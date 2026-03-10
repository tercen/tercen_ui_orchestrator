// Mock data worker — generates synthetic points off the main thread.
// Receives query messages, posts chunk messages back as macrotasks.
//
// Main thread stays free for rAF, scroll, interaction.
// When Tercen HTTP replaces this, the worker does fetch() internally.

self.onmessage = function(e) {
  const { type, id, colStart, colEnd, rowStart, rowEnd,
          chunkSize, pointsPerFacet, xMin, xMax, yMin, yMax } = e.data;

  if (type !== 'query') return;

  const activeCols = colEnd - colStart + 1;
  const activeFacets = activeCols * (rowEnd - rowStart + 1);
  const total = activeFacets * pointsPerFacet;
  const xRange = xMax - xMin;
  const yRange = yMax - yMin;

  let offset = 0;
  while (offset < total) {
    const count = Math.min(chunkSize, total - offset);
    const points = new Array(count);

    for (let k = 0; k < count; k++) {
      const globalIdx = offset + k;
      const facetIdx = Math.floor(globalIdx / pointsPerFacet);
      const localIdx = globalIdx % pointsPerFacet;
      const ci = colStart + (facetIdx % activeCols);
      const ri = rowStart + Math.floor(facetIdx / activeCols);

      const progress = localIdx / pointsPerFacet;
      const margin = xRange * 0.2;  // 20% margin each side
      const baseX = (xMin + margin) + progress * (xRange - 2 * margin);
      const baseY = (yMin + margin) + progress * (yRange - 2 * margin);
      const noiseX = (Math.random() - 0.5) * 2 * margin;
      const noiseY = (Math.random() - 0.5) * 2 * margin;

      points[k] = {
        x: baseX + noiseX,
        y: baseY + noiseY,
        ci, ri,
      };
    }

    offset += count;
    self.postMessage({ type: 'chunk', id, points });
  }

  self.postMessage({ type: 'done', id });
};
