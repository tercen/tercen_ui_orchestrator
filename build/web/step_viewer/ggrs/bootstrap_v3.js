// GGRS V3 Bootstrap - Viewport-driven rendering (aligned with test_streaming.html)

import init, { GGRSRenderer } from "./pkg/ggrs_wasm.js";
import { GgrsGpuV3 } from "./ggrs_gpu_v3.js";
import { PlotState } from "./plot_state.js";
import { InteractionManager } from "./interaction_manager.js";
import { PlotOrchestrator } from "./plot_orchestrator.js";

// WASM initialization state
let wasmInitialized = false;
let wasmInitPromise = null;

/**
 * Ensure WASM is initialized (idempotent)
 */
async function ensureWasmInitialized() {
  if (wasmInitialized) return;
  if (wasmInitPromise) return wasmInitPromise;

  console.log('[bootstrap_v3] Starting WASM initialization...');
  wasmInitPromise = init()
    .then(() => {
      wasmInitialized = true;
      console.log('[bootstrap_v3] WASM initialized successfully');
    })
    .catch((e) => {
      console.error('[bootstrap_v3] WASM initialization failed:', e);
      wasmInitPromise = null;
      throw e;
    });

  return wasmInitPromise;
}

/**
 * Create a WASM renderer instance
 */
function createRenderer(containerId) {
  if (!wasmInitialized) {
    throw new Error('WASM not initialized. Call ensureWasmInitialized() first.');
  }
  console.log(`[bootstrap_v3] Creating renderer for ${containerId}`);
  return new GGRSRenderer(containerId);
}

// ─── Helper Functions ──────────────────────────────────────────────────────

function _parseColor(str) {
  if (str && str.startsWith('#')) {
    const hex = str.slice(1);
    if (hex.length === 6) {
      return [
        parseInt(hex.slice(0, 2), 16) / 255,
        parseInt(hex.slice(2, 4), 16) / 255,
        parseInt(hex.slice(4, 6), 16) / 255,
        1.0,
      ];
    } else if (hex.length === 8) {
      return [
        parseInt(hex.slice(0, 2), 16) / 255,
        parseInt(hex.slice(2, 4), 16) / 255,
        parseInt(hex.slice(4, 6), 16) / 255,
        parseInt(hex.slice(6, 8), 16) / 255,
      ];
    }
  }
  if (str && str.startsWith('rgb(')) {
    const parts = str.slice(4, -1).split(',').map(s => s.trim());
    return [
      parseInt(parts[0]) / 255,
      parseInt(parts[1]) / 255,
      parseInt(parts[2]) / 255,
      1.0,
    ];
  }
  return [0.5, 0.5, 0.5, 1.0];
}

function _packColorU32(r, g, b, a) {
  return (
    ((Math.round(r * 255) & 0xFF) << 24) |
    ((Math.round(g * 255) & 0xFF) << 16) |
    ((Math.round(b * 255) & 0xFF) << 8) |
    (Math.round(a * 255) & 0xFF)
  ) >>> 0;
}

// ─── Chrome rendering helpers ─────────────────────────────────────────────

/**
 * Apply chrome rect layers (from PlotState.renderChrome()) to GPU.
 * Skips text layers (handled separately by _applyTextLayers).
 */
function _applyChrome(gpu, chrome) {
  const TEXT_LAYERS = ['strip_labels_top', 'strip_labels_left', 'axis_labels'];

  for (const [category, elements] of Object.entries(chrome)) {
    if (!elements || elements.length === 0) continue;
    if (TEXT_LAYERS.includes(category)) continue; // Skip text layers

    const rects = elements.map(elem => ({
      x: elem.x,
      y: elem.y,
      w: elem.width,
      h: elem.height,
      color: _parseColor(elem.color || elem.fill),
    }));

    gpu.setLayer(category, rects);
  }
}

/**
 * Apply text layers to HTML div overlay (Layer 3).
 * Text is rendered via DOM, not GPU.
 */
function _applyTextLayers(containerId, chrome) {
  const TEXT_LAYERS = ['strip_labels_top', 'strip_labels_left', 'axis_labels'];

  // Find or create text layer div
  let textLayer = document.getElementById(`${containerId}-text`);
  if (!textLayer) {
    const container = document.getElementById(containerId);
    if (!container) return;

    textLayer = document.createElement('div');
    textLayer.id = `${containerId}-text`;
    textLayer.style.position = 'absolute';
    textLayer.style.top = '0';
    textLayer.style.left = '0';
    textLayer.style.width = '100%';
    textLayer.style.height = '100%';
    textLayer.style.pointerEvents = 'none'; // Don't block interactions
    textLayer.style.zIndex = '3'; // Above SVG chrome (z-index 2)
    container.appendChild(textLayer);
  }

  // Clear previous text
  textLayer.innerHTML = '';

  // Render each text layer
  for (const category of TEXT_LAYERS) {
    const elements = chrome[category];
    if (!elements || elements.length === 0) continue;

    for (const elem of elements) {
      const span = document.createElement('span');
      span.textContent = elem.text;
      span.style.position = 'absolute';
      span.style.left = `${elem.x}px`;
      span.style.top = `${elem.y}px`;
      span.style.fontSize = `${elem.fontSize || 12}px`;
      span.style.fontWeight = elem.fontWeight || '400';
      span.style.color = elem.color || '#374151';
      span.style.fontFamily = 'sans-serif';
      span.style.whiteSpace = 'nowrap';

      // Text alignment
      let transforms = [];
      if (elem.align === 'center') {
        transforms.push('translateX(-50%)');
      } else if (elem.align === 'right') {
        transforms.push('translateX(-100%)');
      }

      // Vertical centering for strip labels
      if (category.includes('strip_labels')) {
        transforms.push('translateY(-50%)');
      }

      if (transforms.length > 0) {
        span.style.transform = transforms.join(' ');
      }

      textLayer.appendChild(span);
    }
  }
}

// ─── Data Source Interface ────────────────────────────────────────────────
//
// Every data source implements one method:
//   streamToQueue(colStart, colEnd, rowStart, rowEnd, dataQueue) → Promise<number>
//
// It pushes arrays of GPU-ready points to dataQueue as they become available.
// The rAF render loop drains the queue independently at 60fps.
// Returns a Promise that resolves with total point count when done.
//
// To swap in Tercen streaming: implement streamToQueue() with HTTP fetch
// in the worker instead of Math.random(). Queue and GPU stay identical.

/**
 * Mock data source — generates synthetic data in a Web Worker.
 * Worker runs off the main thread; chunks arrive as macrotasks via postMessage.
 * Main thread stays free for rAF, scroll, interaction.
 */
class MockDataSource {
  constructor({ totalPoints, chunkSize, nCols, nRows, xMin = -20, xMax = 120, yMin = -20, yMax = 120 }) {
    this.chunkSize = chunkSize;
    this.pointsPerFacet = Math.max(1, Math.floor(totalPoints / (nCols * nRows)));
    this.xMin = xMin;
    this.xMax = xMax;
    this.yMin = yMin;
    this.yMax = yMax;

    this._nextId = 0;
    this._pending = new Map(); // id → { resolve, dataQueue, totalPoints }

    const workerUrl = new URL('mock_data_worker.js', import.meta.url);
    this._worker = new Worker(workerUrl);
    this._worker.onmessage = (e) => this._onMessage(e);
  }

  _onMessage(e) {
    const { type, id, points } = e.data;
    const pending = this._pending.get(id);
    if (!pending) return;

    if (type === 'chunk' && points.length > 0) {
      const gpuPoints = points.map(p => ({
        x: p.x, y: p.y, ci: p.ci, ri: p.ri,
        color_packed: 0x0000FFFF, size: 3.0,
      }));
      pending.dataQueue.push(gpuPoints);
      pending.totalPoints += gpuPoints.length;
    } else if (type === 'done') {
      pending.resolve(pending.totalPoints);
      this._pending.delete(id);
    }
  }

  /**
   * Fire a query to the worker. Chunks arrive as macrotasks and are pushed
   * to dataQueue. Returns Promise<number> that resolves with total points
   * when the worker finishes. Multiple concurrent calls are supported.
   */
  streamToQueue(colStart, colEnd, rowStart, rowEnd, dataQueue) {
    const id = this._nextId++;
    return new Promise(resolve => {
      this._pending.set(id, { resolve, dataQueue, totalPoints: 0 });
      this._worker.postMessage({
        type: 'query', id,
        colStart, colEnd, rowStart, rowEnd,
        chunkSize: this.chunkSize,
        pointsPerFacet: this.pointsPerFacet,
        xMin: this.xMin, xMax: this.xMax,
        yMin: this.yMin, yMax: this.yMax,
      });
    });
  }

  destroy() {
    this._worker.terminate();
    this._pending.clear();
  }
}

// ─── Range Computation Helpers ────────────────────────────────────────────

// computeOverlap removed — append-only GPU architecture, no filtering needed

/**
 * Compute NEW rectangles to load (facets in needed but not in loaded).
 * Returns array of 0-4 rectangles (could be empty if needed ⊆ loaded).
 */
function computeNewRectangles(needed, loaded) {
  if (!loaded || loaded.colEnd === 0) {
    // No previous data - load entire needed range
    return [needed];
  }

  const newRects = [];

  // Right extension (new columns on right edge)
  if (needed.colEnd > loaded.colEnd) {
    newRects.push({
      colStart: Math.max(loaded.colEnd, needed.colStart),
      colEnd: needed.colEnd,
      rowStart: needed.rowStart,
      rowEnd: needed.rowEnd,
    });
  }

  // Left extension (new columns on left edge)
  if (needed.colStart < loaded.colStart) {
    newRects.push({
      colStart: needed.colStart,
      colEnd: Math.min(loaded.colStart, needed.colEnd),
      rowStart: needed.rowStart,
      rowEnd: needed.rowEnd,
    });
  }

  // Bottom extension (new rows on bottom, only in column overlap)
  if (needed.rowEnd > loaded.rowEnd) {
    const overlapColStart = Math.max(needed.colStart, loaded.colStart);
    const overlapColEnd = Math.min(needed.colEnd, loaded.colEnd);
    if (overlapColEnd > overlapColStart) {
      newRects.push({
        colStart: overlapColStart,
        colEnd: overlapColEnd,
        rowStart: Math.max(loaded.rowEnd, needed.rowStart),
        rowEnd: needed.rowEnd,
      });
    }
  }

  // Top extension (new rows on top, only in column overlap)
  if (needed.rowStart < loaded.rowStart) {
    const overlapColStart = Math.max(needed.colStart, loaded.colStart);
    const overlapColEnd = Math.min(needed.colEnd, loaded.colEnd);
    if (overlapColEnd > overlapColStart) {
      newRects.push({
        colStart: overlapColStart,
        colEnd: overlapColEnd,
        rowStart: needed.rowStart,
        rowEnd: Math.min(loaded.rowStart, needed.rowEnd),
      });
    }
  }

  return newRects;
}

// filterPointsByRange removed — append-only GPU architecture, vertex shader clips by viewport

/**
 * Request data check (debounced to avoid checking on every scroll tick).
 * Moved out of setViewport() - data loading is now independent and async.
 */
function _requestDataCheck(containerId) {
  const instance = ggrsV3._gpuInstances.get(containerId);
  if (!instance) return;

  // Debounce: clear existing timeout, set new one
  if (instance._dataCheckTimeout) {
    clearTimeout(instance._dataCheckTimeout);
  }

  instance._dataCheckTimeout = setTimeout(() => {
    // Skip if initial streaming is in progress (viewport-driven loading takes over after DATA_STREAMING completes)
    const currentState = instance.orchestrator.state;
    if (currentState === 'DATA_STREAMING') {
      console.log('[bootstrap_v3] Skipping data check - initial stream in progress');
      return;
    }

    // Call checkAndLoadNewFacets (which triggers onLoadFacets callback)
    // Supports concurrent loads via snapshot system - no blocking needed
    instance.plotState.checkAndLoadNewFacets();
  }, 150); // 150ms debounce - increased to reduce hitching during scroll
}

/**
 * Start continuous render loop for smooth scrolling.
 *
 * Simplified architecture:
 * - Scroll events just update viewport.row/col (instant, no work)
 * - This loop runs at 60fps, reads viewport state, animates GPU offset
 * - Chrome rebuilds only when data chunks arrive (not on every scroll)
 *
 * Benefits:
 * - Decouples scroll events from rendering
 * - Smooth 60fps animation independent of event frequency
 * - Rapid scrolling doesn't block (just updates numbers)
 */
function _startContinuousRenderLoop(containerId) {
  const instance = ggrsV3._gpuInstances.get(containerId);
  if (!instance) return;

  const plotState = instance.plotState;
  const gpu = instance.gpu;

  // Initialize animation state
  if (!instance._animation) {
    instance._animation = {
      isAnimating: false,
      startTime: 0,
      duration: 200, // ms
      startCol: 0,
      startRow: 0,
      targetCol: 0,
      targetRow: 0,
      startVisibleCols: 0,
      startVisibleRows: 0,
      targetVisibleCols: 0,
      targetVisibleRows: 0,
      animationId: null,
    };
  }

  const anim = instance._animation;

  const renderLoop = () => {
    const vp = plotState.viewport;

    // Check if viewport OR zoom target changed (from InteractionManager)
    const targetChanged =
      Math.abs(vp.col - anim.targetCol) > 0.001 ||
      Math.abs(vp.row - anim.targetRow) > 0.001 ||
      Math.abs(vp.visibleCols - anim.targetVisibleCols) > 0.001 ||
      Math.abs(vp.visibleRows - anim.targetVisibleRows) > 0.001;

    // IMPROVED: Allow scroll/zoom to interrupt current animation (responsive continuous interaction)
    // To revert to old behavior (drop second event), add back: && !anim.isAnimating
    if (targetChanged) {
      // New target - start/restart animation from CURRENT position/zoom (not previous target)
      // This allows smooth interruption - each interaction retargets from where we are now
      anim.startCol = anim.isAnimating ? plotState.viewport.col : (anim.targetCol || vp.col);
      anim.startRow = anim.isAnimating ? plotState.viewport.row : (anim.targetRow || vp.row);
      anim.startVisibleCols = anim.isAnimating ? plotState.viewport.visibleCols : (anim.targetVisibleCols || vp.visibleCols);
      anim.startVisibleRows = anim.isAnimating ? plotState.viewport.visibleRows : (anim.targetVisibleRows || vp.visibleRows);
      anim.targetCol = vp.col;
      anim.targetRow = vp.row;
      anim.targetVisibleCols = vp.visibleCols;
      anim.targetVisibleRows = vp.visibleRows;
      anim.startTime = performance.now();
      anim.isAnimating = true;

      // Trigger async data check (debounced)
      _requestDataCheck(containerId);
    }

    // Interpolate viewport position AND zoom if animating
    if (anim.isAnimating) {
      const elapsed = performance.now() - anim.startTime;
      const progress = Math.min(elapsed / anim.duration, 1.0);
      const eased = 1 - Math.pow(1 - progress, 3); // Ease-out cubic

      // Interpolate viewport position
      const interpolatedCol = anim.startCol + (anim.targetCol - anim.startCol) * eased;
      const interpolatedRow = anim.startRow + (anim.targetRow - anim.startRow) * eased;

      // Interpolate zoom level (visibleCols/visibleRows)
      const interpolatedVisibleCols = anim.startVisibleCols + (anim.targetVisibleCols - anim.startVisibleCols) * eased;
      const interpolatedVisibleRows = anim.startVisibleRows + (anim.targetVisibleRows - anim.startVisibleRows) * eased;

      // Update PlotState viewport with interpolated values
      plotState.viewport.col = interpolatedCol;
      plotState.viewport.row = interpolatedRow;
      plotState.viewport.visibleCols = interpolatedVisibleCols;
      plotState.viewport.visibleRows = interpolatedVisibleRows;

      if (progress >= 1.0) {
        // Animation complete - snap to final values
        plotState.viewport.col = anim.targetCol;
        plotState.viewport.row = anim.targetRow;
        plotState.viewport.visibleCols = anim.targetVisibleCols;
        plotState.viewport.visibleRows = anim.targetVisibleRows;
        anim.isAnimating = false;
      }
    }

    // Recompute layout based on current (interpolated) viewport
    plotState._recomputeLayout();
    const layout = plotState.layout;

    // Rebuild chrome every frame during animation (positions calculated relative to interpolated viewport)
    // Outside animation, chrome only rebuilds when data arrives
    if (anim.isAnimating) {
      const chrome = plotState.renderChrome();
      _applyChrome(gpu, chrome);
      _applyTextLayers(containerId, chrome);
    }

    // Drain data queue — push any pending chunks to GPU
    const inst = ggrsV3._gpuInstances.get(containerId);
    if (inst && inst._dataQueue.length > 0) {
      // Process one chunk per frame to keep frame times short
      const chunk = inst._dataQueue.shift();
      gpu.appendDataPoints(chunk);
    }

    // Sync layout state to GPU
    const layoutState = plotState.buildLayoutState();
    gpu.syncLayoutState(JSON.stringify(layoutState));

    // Continue loop
    anim.animationId = requestAnimationFrame(renderLoop);
  };

  // Start the loop
  anim.animationId = requestAnimationFrame(renderLoop);
  console.log(`[bootstrap_v3] Started continuous render loop for ${containerId}`);
}

// ─── Main API ─────────────────────────────────────────────────────────────

const ggrsV3 = {
  ensureWasmInitialized,
  createRenderer,
  _gpuInstances: new Map(),

  /**
   * Ensure GPU is initialized for a container.
   * Creates GPU, PlotState, and InteractionManager on first call.
   * Updates canvas/layout dimensions on subsequent calls (e.g., resize).
   */
  async ggrsV3EnsureGpu(containerId, width, height, renderer) {
    console.log(`[bootstrap_v3] ensureGpu(${containerId}, ${width}x${height})`);

    // If already initialized, just update dimensions
    if (ggrsV3._gpuInstances.has(containerId)) {
      console.log(`[bootstrap_v3] GPU already initialized, updating dimensions`);
      const instance = ggrsV3._gpuInstances.get(containerId);
      instance.gpu.resize(width, height);
      instance.plotState.resize(width, height);
      return;
    }

    // Find or create canvas
    let canvas = document.getElementById(`${containerId}-canvas`);
    if (!canvas) {
      const container = document.getElementById(containerId);
      if (!container) {
        throw new Error(`Container ${containerId} not found`);
      }
      canvas = document.createElement('canvas');
      canvas.id = `${containerId}-canvas`;
      canvas.style.position = 'absolute';
      canvas.style.top = '0';
      canvas.style.left = '0';
      canvas.style.width = '100%';
      canvas.style.height = '100%';
      canvas.style.display = 'block';
      canvas.style.zIndex = '1';
      container.appendChild(canvas);
    }

    // Create GPU
    const gpu = new GgrsGpuV3();
    await gpu.init(canvas);
    gpu.resize(width, height);

    // Create interaction div overlay
    let interactionDiv = document.getElementById(`${containerId}-interaction`);
    if (!interactionDiv) {
      interactionDiv = document.createElement('div');
      interactionDiv.id = `${containerId}-interaction`;
      interactionDiv.style.position = 'absolute';
      interactionDiv.style.top = '0';
      interactionDiv.style.left = '0';
      interactionDiv.style.width = '100%';
      interactionDiv.style.height = '100%';
      interactionDiv.style.pointerEvents = 'all';
      interactionDiv.style.zIndex = '10';
      canvas.parentElement.appendChild(interactionDiv);
    }

    // Create PlotOrchestrator (state machine) and set proper state sequence
    const orchestrator = new PlotOrchestrator(containerId);

    // By this point, WASM is initialized (ensured in ensureWasmInitialized)
    if (wasmInitialized) {
      orchestrator.setState('WASM_READY');
    }

    // Renderer was created and passed in
    if (renderer) {
      orchestrator.setState('RENDERER_READY', { renderer });
    }

    // GPU just created successfully
    orchestrator.setState('GPU_READY', { width, height });

    // Create PlotState (centralized state)
    const plotState = new PlotState({
      canvasWidth: width,
      canvasHeight: height,
      cellSpacing: 10,
      initialVisibleCols: 4.0,  // Test: 4 columns
      initialVisibleRows: 3.0,  // Test: 3 rows
    });

    // Background facet loading callback (triggered when viewport changes - scroll/zoom)
    // Only loads NEW facets — existing data stays in GPU buffer untouched
    plotState.onLoadFacets = async (neededRange, loadId) => {
      try {
      const loadedRange = plotState.loadedFacets;

      console.log(`[bootstrap_v3] onLoadFacets #${loadId}: needed [${neededRange.colStart},${neededRange.colEnd}) x [${neededRange.rowStart},${neededRange.rowEnd}), loaded [${loadedRange.colStart},${loadedRange.colEnd}) x [${loadedRange.rowStart},${loadedRange.rowEnd})`);

      // Compute NEW rectangles only (facets in needed but not in loaded)
      const newRects = computeNewRectangles(neededRange, loadedRange);

      if (newRects.length === 0) {
        console.log(`[bootstrap_v3] No new facets needed — all already loaded`);
        plotState.markFacetsLoaded(neededRange.colStart, neededRange.colEnd, neededRange.rowStart, neededRange.rowEnd);
        plotState.removeLoadSnapshot(loadId);
        return;
      }

      newRects.forEach((rect, i) => {
        console.log(`[bootstrap_v3]   New rect ${i + 1}: cols [${rect.colStart}, ${rect.colEnd}), rows [${rect.rowStart}, ${rect.rowEnd})`);
      });

      // Load ONLY new rectangles — existing data stays in GPU untouched
      const inst = ggrsV3._gpuInstances.get(containerId);
      for (const rect of newRects) {
        const cs = rect.colStart;
        const ce = Math.max(0, rect.colEnd - 1);  // exclusive → inclusive
        const rs = rect.rowStart;
        const re = Math.max(0, rect.rowEnd - 1);   // exclusive → inclusive

        const rectPoints = await inst.dataSource.streamToQueue(cs, ce, rs, re, inst._dataQueue);
        console.log(`[bootstrap_v3] Loaded rect [${cs},${ce}]x[${rs},${re}]: ${rectPoints} points`);
      }

      // Expand loaded range to include new facets
      const expandedColStart = Math.min(neededRange.colStart, loadedRange.colStart);
      const expandedColEnd = Math.max(neededRange.colEnd, loadedRange.colEnd);
      const expandedRowStart = Math.min(neededRange.rowStart, loadedRange.rowStart);
      const expandedRowEnd = Math.max(neededRange.rowEnd, loadedRange.rowEnd);
      plotState.markFacetsLoaded(expandedColStart, expandedColEnd, expandedRowStart, expandedRowEnd);
      plotState.removeLoadSnapshot(loadId);

      // Rebuild chrome for new facet labels
      const chrome = plotState.renderChrome();
      _applyChrome(gpu, chrome);
      _applyTextLayers(containerId, chrome);

      } catch (err) {
        console.error(`[bootstrap_v3] onLoadFacets error:`, err);
      }
    };

    // Chrome rebuild callback (used by InteractionManager)
    const onChromeRebuild = () => {
      const chrome = plotState.renderChrome();
      _applyChrome(gpu, chrome);           // GPU: rects (strips, axes, ticks)
      _applyTextLayers(containerId, chrome); // DOM: text (labels)
    };

    // Create InteractionManager (viewport-driven, no WASM calls)
    const interactionManager = new InteractionManager(
      containerId, gpu, interactionDiv, plotState, onChromeRebuild,
    );

    // Create mock data source (replace with TercenDataSource for real data)
    const dataSource = new MockDataSource({
      totalPoints: 5000000,
      chunkSize: 15000,
      nCols: plotState._grid?.totalCols || 10,
      nRows: plotState._grid?.totalRows || 10,
    });

    ggrsV3._gpuInstances.set(containerId, {
      gpu, renderer, interactionManager, plotState, orchestrator, dataSource,
      _dataQueue: [],  // Shared queue: producers push chunks, render loop drains
    });

    // Start continuous render loop (60fps) - decoupled from scroll events
    // Handles smooth scrolling via GPU offset animation
    _startContinuousRenderLoop(containerId);

    console.log(`[bootstrap_v3] Created GgrsGpuV3 + PlotState + InteractionManager + continuous render loop for ${containerId}`);
  },

  /**
   * Get GPU instance for a container
   */
  ggrsV3GetGpu(containerId) {
    const instance = ggrsV3._gpuInstances.get(containerId);
    return instance ? instance.gpu : null;
  },

  /**
   * Set plot metadata from WASM initPlotStream result (Phase 2).
   * Populates PlotState with grid dimensions, axis ranges, facet labels, chrome styles.
   */
  ggrsV3SetPlotMetadata(containerId, metadataJson) {
    console.log(`[bootstrap_v3] setPlotMetadata(${containerId})`);
    const instance = ggrsV3._gpuInstances.get(containerId);
    if (!instance) {
      throw new Error(`No GPU instance for ${containerId}`);
    }
    const metadata = typeof metadataJson === 'string'
      ? JSON.parse(metadataJson)
      : metadataJson;
    instance.plotState.setMetadata(metadata);
    instance.orchestrator.setState('METADATA_READY', { metadata });
    console.log(`[bootstrap_v3] Plot metadata set:`, metadata);
  },

  /**
   * Configure viewport with grid dimensions and axis ranges.
   * Call after initPlotStream returns metadata (Phase 2) or with mock values (Phase 1).
   */
  ggrsV3SetViewportConfig(containerId, config) {
    console.log(`[bootstrap_v3] setViewportConfig(${containerId})`, config);
    const instance = ggrsV3._gpuInstances.get(containerId);
    if (!instance) {
      throw new Error(`No GPU instance for ${containerId}`);
    }
    instance.plotState.setGridConfig(config);
  },

  /**
   * Render chrome from PlotState and apply to GPU (rects) and DOM (text).
   */
  ggrsV3RenderChrome(containerId, chromeJsonOrUndefined) {
    console.log(`[bootstrap_v3] renderChrome(${containerId})`);
    const instance = ggrsV3._gpuInstances.get(containerId);
    if (!instance) {
      throw new Error(`No GPU instance for ${containerId}`);
    }

    let chrome;
    if (chromeJsonOrUndefined) {
      // External chrome data (from test harness or WASM)
      chrome = typeof chromeJsonOrUndefined === 'string'
        ? JSON.parse(chromeJsonOrUndefined)
        : chromeJsonOrUndefined;
    } else {
      // Generate from PlotState
      chrome = instance.plotState.renderChrome();
    }

    _applyChrome(instance.gpu, chrome);           // GPU: rects
    _applyTextLayers(containerId, chrome);         // DOM: text
    instance.orchestrator.setState('CHROME_READY');
    console.log(`[bootstrap_v3] Chrome rendered: ${Object.keys(chrome).length} categories`);
  },

  // ── COMMENTED OUT: Manual sync layout (replaced by continuous render loop) ──
  //
  // Old approach: called from interaction handlers on every scroll/zoom event
  // New approach: continuous 60fps render loop handles all GPU sync + animation
  //
  // Benefits of continuous loop:
  // - Decouples scroll events from rendering (scroll just updates numbers)
  // - Guaranteed smooth 60fps (not event-dependent)
  // - No blocking work in scroll handlers
  // - Chrome only rebuilds when data arrives (not on every scroll)
  //
  // /**
  //  * Sync layout state from PlotState to GPU with smooth scrolling.
  //  */
  // ggrsV3SyncLayout(containerId) {
  //   ...
  // },

  /**
   * Get current viewport dimensions from PlotState (single source of truth).
   * Returns { visibleCols, visibleRows } for Dart to use in facet filters.
   */
  ggrsV3GetViewport(containerId) {
    const instance = ggrsV3._gpuInstances.get(containerId);
    if (!instance) {
      throw new Error(`No GPU instance for ${containerId}`);
    }
    const { visibleCols, visibleRows } = instance.plotState.viewport;
    return { visibleCols, visibleRows };
  },

  /**
   * Set data points directly on GPU.
   */
  ggrsV3SetDataPoints(containerId, points) {
    const instance = ggrsV3._gpuInstances.get(containerId);
    if (!instance) {
      throw new Error(`No GPU instance for ${containerId}`);
    }
    instance.gpu.setDataPoints(points);
  },

  /**
   * Stream data for the given facet range with progressive rendering.
   * Uses the instance's dataSource async generator — same path for mock and real data.
   * Each chunk is pushed to _dataQueue; the rAF render loop drains independently.
   *
   * @param {string} containerId - Container ID
   * @param {Object} range - { colStart, colEnd, rowStart, rowEnd } (all inclusive)
   */
  async ggrsV3StreamData(containerId, range) {
    const colStart = range.colStart;
    const colEnd = range.colEnd;
    const rowStart = range.rowStart;
    const rowEnd = range.rowEnd;
    const instance = ggrsV3._gpuInstances.get(containerId);
    if (!instance || !instance.dataSource) {
      throw new Error(`No GPU/dataSource instance for ${containerId}`);
    }

    console.log(`[bootstrap_v3] Streaming data for facets cols [${colStart}, ${colEnd}], rows [${rowStart}, ${rowEnd}]`);

    // Transition to DATA_STREAMING state
    instance.orchestrator.setState('DATA_STREAMING');

    const totalPointsRendered = await instance.dataSource.streamToQueue(
      colStart, colEnd, rowStart, rowEnd, instance._dataQueue,
    );

    // Mark loaded facets (exclusive end)
    instance.plotState.markFacetsLoaded(colStart, colEnd + 1, rowStart, rowEnd + 1);

    // Transition to READY
    instance.orchestrator.setState('DATA_READY', { pointCount: totalPointsRendered });
    instance.orchestrator.setState('READY');

    console.log(`[bootstrap_v3] Streaming complete: ${totalPointsRendered} points`);
    return totalPointsRendered;
  },

  /**
   * Cleanup GPU and interaction manager.
   */
  ggrsV3Cleanup(containerId) {
    console.log(`[bootstrap_v3] cleanup(${containerId})`);
    const instance = ggrsV3._gpuInstances.get(containerId);
    if (instance) {
      // Stop continuous render loop
      if (instance._animation && instance._animation.animationId) {
        cancelAnimationFrame(instance._animation.animationId);
      }
      if (instance.gpu) instance.gpu.destroy();
      if (instance.interactionManager) instance.interactionManager.destroy();
      if (instance.dataSource) instance.dataSource.destroy();
      if (instance.plotState) instance.plotState.destroy();
    }
    ggrsV3._gpuInstances.delete(containerId);
  },
};

// Export to global scope
window.ggrsV3 = ggrsV3;

console.log('[bootstrap_v3] V3 bootstrap loaded (PlotState-driven rendering)');
