import 'dart:math';

import '../../domain/models/workflow_models.dart';
import '../../domain/services/data_service.dart';

/// Mock implementation with multiple test workflows.
///
/// Toggle [_activeWorkflow] to switch between them.
/// All steps start in [StepState.init] — the mock execution engine
/// handles state progression via EventBus when run/stop/reset are invoked.
class MockDataService implements DataService {
  WorkflowModel? _cached;
  final _rng = Random();
  bool _firstLoad = true;

  /// Which workflow to display.
  /// 'rnaseq'     = RNAseq Data Connector (11 steps, 2 joins)
  /// 'crabs'      = Crabs Workflow (5 steps, fan-out, no joins)
  /// 'cluster'    = Cluster Interpretation (11 steps, deep fan-out, InStep entry)
  /// 'test22'     = test 22 (22 steps, 8-way fan-out, join, melt, views)
  static const String _activeWorkflow = 'test22';

  Future<void> _jitteredDelay(int minMs, int maxMs) async {
    final ms = minMs + _rng.nextInt(maxMs - minMs + 1);
    await Future.delayed(Duration(milliseconds: ms));
  }

  @override
  Future<WorkflowModel> fetchWorkflow(
      String workflowId, String projectId) async {
    if (_firstLoad) {
      _firstLoad = false;
      await _jitteredDelay(800, 1800); // Cold start
    } else {
      await _jitteredDelay(300, 800); // Warm cache
    }
    switch (_activeWorkflow) {
      case 'crabs':
        _cached = _buildCrabsWorkflow();
        break;
      case 'cluster':
        _cached = _buildClusterInterpretation();
        break;
      case 'test22':
        _cached = _buildTest22Workflow();
        break;
      default:
        _cached = _buildRnaseqWorkflow();
    }
    return _cached!;
  }

  @override
  Future<void> renameStep(String stepId, String newName) async {
    await _jitteredDelay(150, 400);
    if (_cached != null) {
      final step = _cached!.steps.firstWhere((s) => s.id == stepId);
      step.name = newName;
    }
  }

  @override
  Future<void> moveStep(String stepId, double x, double y) async {
    await _jitteredDelay(80, 200);
    if (_cached != null) {
      final step = _cached!.steps.firstWhere((s) => s.id == stepId);
      step.rectangle?.x = x;
      step.rectangle?.y = y;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // Crabs Workflow — from stage.tercen.com
  // ID: f062cb164c337a519d8cf050c2f323f2
  //
  // Fan-out topology: 1 table → 3 parallel data steps, PCA → 1 more
  //
  //   Crabs Data ──→ Heatmap
  //              ├──→ Multi Pairwise
  //              └──→ PCA ──→ Multi Pairwise PC view
  // ═══════════════════════════════════════════════════════════════════

  WorkflowModel _buildCrabsWorkflow() {
    final steps = <StepModel>[];
    final links = <LinkModel>[];

    steps.add(StepModel(
      id: 'ts-crabs',
      name: 'Crabs Data',
      groupId: '',
      kind: StepKind.tableStep,
    ));

    steps.add(StepModel(
      id: 'ds-heatmap',
      name: 'Heatmap',
      groupId: '',
      kind: StepKind.dataStep,
    ));
    links.add(const LinkModel(
      inputStepId: 'ds-heatmap',
      outputStepId: 'ts-crabs',
    ));

    steps.add(StepModel(
      id: 'ds-multi-pairwise',
      name: 'Multi Pairwise',
      groupId: '',
      kind: StepKind.dataStep,
    ));
    links.add(const LinkModel(
      inputStepId: 'ds-multi-pairwise',
      outputStepId: 'ts-crabs',
    ));

    steps.add(StepModel(
      id: 'ds-pca',
      name: 'PCA',
      groupId: '',
      kind: StepKind.dataStep,
    ));
    links.add(const LinkModel(
      inputStepId: 'ds-pca',
      outputStepId: 'ts-crabs',
    ));

    steps.add(StepModel(
      id: 'ds-multi-pc-view',
      name: 'Multi Pairwise PC view',
      groupId: '',
      kind: StepKind.dataStep,
    ));
    links.add(const LinkModel(
      inputStepId: 'ds-multi-pc-view',
      outputStepId: 'ds-pca',
    ));

    return WorkflowModel(
      id: 'f062cb164c337a519d8cf050c2f323f2',
      name: 'Crabs Workflow',
      projectId: 'b8bf50d6a3865a60a0bc0dd4e352ebcb',
      steps: steps,
      links: links,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Cluster Interpretation — group step from Flow Immunophenotyping
  // Workflow: 6056012f5d0da9ea7fe076190c3244b4
  // Group:    4acc795d-f726-4538-8f3f-d3682b4c80c4
  //
  // 11 steps, deep fan-out, InStep entry point:
  //
  //   Input ──→ Marker Enrichment Score ──→ Enrichment Heatmap ──→ Ordered Enrichment Heatmap ──→ View
  //                                     │                                                      └──→ Cluster Markers ──→ View
  //                                     │                                                                            └──→ Cluster Profiles ──→ Output
  //                                     │                                                                                                   └──→ View
  //                                     └──→ Marker expression per cluster
  // ═══════════════════════════════════════════════════════════════════

  WorkflowModel _buildClusterInterpretation() {
    final steps = <StepModel>[];
    final links = <LinkModel>[];

    steps.add(StepModel(
      id: 'b7f8d18e',
      name: 'Input',
      groupId: '4acc795d',
      kind: StepKind.inStep,
    ));

    steps.add(StepModel(
      id: 'd9faca40',
      name: 'Marker Enrichment Score',
      groupId: '4acc795d',
      kind: StepKind.dataStep,
    ));
    links.add(const LinkModel(
      inputStepId: 'd9faca40',
      outputStepId: 'b7f8d18e',
    ));

    steps.add(StepModel(
      id: '89e2c483',
      name: 'Enrichment Heatmap',
      groupId: '4acc795d',
      kind: StepKind.dataStep,
    ));
    links.add(const LinkModel(
      inputStepId: '89e2c483',
      outputStepId: 'd9faca40',
    ));

    steps.add(StepModel(
      id: '50ba414c',
      name: 'Ordered Enrichment Heatmap',
      groupId: '4acc795d',
      kind: StepKind.dataStep,
    ));
    links.add(const LinkModel(
      inputStepId: '50ba414c',
      outputStepId: '89e2c483',
    ));

    steps.add(StepModel(
      id: '7ee10b97',
      name: 'View',
      groupId: '4acc795d',
      kind: StepKind.viewStep,
    ));
    links.add(const LinkModel(
      inputStepId: '7ee10b97',
      outputStepId: '50ba414c',
    ));

    steps.add(StepModel(
      id: '6418bff0',
      name: 'Cluster Markers',
      groupId: '4acc795d',
      kind: StepKind.dataStep,
    ));
    links.add(const LinkModel(
      inputStepId: '6418bff0',
      outputStepId: '50ba414c',
    ));

    steps.add(StepModel(
      id: '1405ab2c',
      name: 'View',
      groupId: '4acc795d',
      kind: StepKind.viewStep,
    ));
    links.add(const LinkModel(
      inputStepId: '1405ab2c',
      outputStepId: '6418bff0',
    ));

    steps.add(StepModel(
      id: '56ccde5c',
      name: 'Cluster Profiles',
      groupId: '4acc795d',
      kind: StepKind.dataStep,
    ));
    links.add(const LinkModel(
      inputStepId: '56ccde5c',
      outputStepId: '6418bff0',
    ));

    steps.add(StepModel(
      id: 'cf80bb7e',
      name: 'Output',
      groupId: '4acc795d',
      kind: StepKind.outStep,
    ));
    links.add(const LinkModel(
      inputStepId: 'cf80bb7e',
      outputStepId: '56ccde5c',
    ));

    steps.add(StepModel(
      id: 'fb1eb205',
      name: 'View',
      groupId: '4acc795d',
      kind: StepKind.viewStep,
    ));
    links.add(const LinkModel(
      inputStepId: 'fb1eb205',
      outputStepId: '56ccde5c',
    ));

    steps.add(StepModel(
      id: '67df0de4',
      name: 'Marker expression per cluster',
      groupId: '4acc795d',
      kind: StepKind.dataStep,
    ));
    links.add(const LinkModel(
      inputStepId: '67df0de4',
      outputStepId: 'd9faca40',
    ));

    return WorkflowModel(
      id: '4acc795d-f726-4538-8f3f-d3682b4c80c4',
      name: 'Cluster Interpretation',
      projectId: '6056012f5d0da9ea7fe076190c3244b4',
      steps: steps,
      links: links,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // test 22 — from stage.tercen.com (martin.english personal)
  // ID: 333e3ae3f7953437b6431c61f802eea5
  //
  // 22 steps, 2 entrypoints, 1 join, 1 melt, 3 views, 8-way fan-out from PCA
  // ═══════════════════════════════════════════════════════════════════

  static StepRectangle _rect(int lane, int depth) {
    final cx = lane * 180.0 + 100.0;
    final cy = depth * 60.0 + 100.0;
    return StepRectangle(x: cx - 60, y: cy - 27.5);
  }

  WorkflowModel _buildTest22Workflow() {
    final steps = <StepModel>[];
    final links = <LinkModel>[];

    steps.add(StepModel(
      id: '1c782532', name: 'Cell Ranger Data', groupId: '',
      kind: StepKind.tableStep,
      rectangle: _rect(0, 0),
    ));
    steps.add(StepModel(
      id: '3cbbfaa7', name: 'README.md', groupId: '',
      kind: StepKind.tableStep,
      rectangle: _rect(4, 0),
    ));

    steps.add(StepModel(
      id: 'c45b2c6d', name: 'QC step', groupId: '',
      kind: StepKind.dataStep,
      rectangle: _rect(0, 1),
    ));
    links.add(const LinkModel(inputStepId: 'c45b2c6d', outputStepId: '1c782532'));

    steps.add(StepModel(
      id: 'b576ee55', name: 'QC filters and normalization', groupId: '',
      kind: StepKind.dataStep,
      rectangle: _rect(0, 2),
    ));
    links.add(const LinkModel(inputStepId: 'b576ee55', outputStepId: 'c45b2c6d'));

    steps.add(StepModel(
      id: 'cbc89c44', name: 'Find variable features', groupId: '',
      kind: StepKind.dataStep,
      rectangle: _rect(0, 3),
    ));
    links.add(const LinkModel(inputStepId: 'cbc89c44', outputStepId: 'b576ee55'));

    steps.add(StepModel(
      id: '571e2a12', name: 'PCA on 2K most variable genes', groupId: '',
      kind: StepKind.dataStep,
      rectangle: _rect(0, 4),
    ));
    links.add(const LinkModel(inputStepId: '571e2a12', outputStepId: 'cbc89c44'));

    steps.add(StepModel(
      id: 'c8c16d44', name: 'View PCA Results', groupId: '',
      kind: StepKind.dataStep,
      rectangle: _rect(0, 5),
    ));
    links.add(const LinkModel(inputStepId: 'c8c16d44', outputStepId: '571e2a12'));

    steps.add(StepModel(
      id: 'ca1777ef', name: 'SNN Graph Clustering', groupId: '',
      kind: StepKind.dataStep,
      rectangle: _rect(1, 5),
    ));
    links.add(const LinkModel(inputStepId: 'ca1777ef', outputStepId: '571e2a12'));

    steps.add(StepModel(
      id: 'a1b9e796', name: 'Data step', groupId: '',
      kind: StepKind.dataStep,
      rectangle: _rect(2, 5),
    ));
    links.add(const LinkModel(inputStepId: 'a1b9e796', outputStepId: '571e2a12'));

    steps.add(StepModel(
      id: 'd707d3b1', name: 'Data step 1', groupId: '',
      kind: StepKind.dataStep,
      rectangle: _rect(3, 5),
    ));
    links.add(const LinkModel(inputStepId: 'd707d3b1', outputStepId: '571e2a12'));

    steps.add(StepModel(
      id: 'e79df6d6', name: 'Data step 2', groupId: '',
      kind: StepKind.dataStep,
      rectangle: _rect(5, 5),
    ));
    links.add(const LinkModel(inputStepId: 'e79df6d6', outputStepId: '571e2a12'));

    steps.add(StepModel(
      id: 'fd8e47f4', name: 'Data step 3', groupId: '',
      kind: StepKind.dataStep,
      rectangle: _rect(6, 5),
    ));
    links.add(const LinkModel(inputStepId: 'fd8e47f4', outputStepId: '571e2a12'));

    steps.add(StepModel(
      id: 'c1aac962', name: 'Data step 4', groupId: '',
      kind: StepKind.dataStep,
      rectangle: _rect(7, 5),
    ));
    links.add(const LinkModel(inputStepId: 'c1aac962', outputStepId: '571e2a12'));

    steps.add(StepModel(
      id: '3cae27c9', name: 'View 3', groupId: '',
      kind: StepKind.viewStep,
      rectangle: _rect(0, 6),
    ));
    links.add(const LinkModel(inputStepId: '3cae27c9', outputStepId: 'c8c16d44'));

    steps.add(StepModel(
      id: '2a1cf509', name: 'View clusters', groupId: '',
      kind: StepKind.dataStep,
      rectangle: _rect(1, 6),
    ));
    links.add(const LinkModel(inputStepId: '2a1cf509', outputStepId: 'ca1777ef'));

    steps.add(StepModel(
      id: 'bf643020', name: 'Differential analysis - find markers', groupId: '',
      kind: StepKind.dataStep,
      rectangle: _rect(2, 6),
    ));
    links.add(const LinkModel(inputStepId: 'bf643020', outputStepId: 'ca1777ef'));

    steps.add(StepModel(
      id: '6279eddd', name: 'View Differentially Expressed Markers', groupId: '',
      kind: StepKind.dataStep,
      rectangle: _rect(2, 7),
    ));
    links.add(const LinkModel(inputStepId: '6279eddd', outputStepId: 'bf643020'));

    steps.add(StepModel(
      id: '6b29c369', name: 'Join', groupId: '',
      kind: StepKind.joinStep,
      rectangle: _rect(3, 7),
    ));
    links.add(const LinkModel(inputStepId: '6b29c369', outputStepId: 'bf643020'));
    links.add(const LinkModel(inputStepId: '6b29c369', outputStepId: '3cbbfaa7'));

    steps.add(StepModel(
      id: 'e0c6c7a6', name: 'Gather', groupId: '',
      kind: StepKind.meltStep,
      rectangle: _rect(3, 8),
    ));
    links.add(const LinkModel(inputStepId: 'e0c6c7a6', outputStepId: '6b29c369'));

    steps.add(StepModel(
      id: '1f581e6c', name: 'Data step 5', groupId: '',
      kind: StepKind.dataStep,
      rectangle: _rect(3, 9),
    ));
    links.add(const LinkModel(inputStepId: '1f581e6c', outputStepId: 'e0c6c7a6'));

    steps.add(StepModel(
      id: 'f57359f8', name: 'View 5', groupId: '',
      kind: StepKind.viewStep,
      rectangle: _rect(3, 10),
    ));
    links.add(const LinkModel(inputStepId: 'f57359f8', outputStepId: '1f581e6c'));

    steps.add(StepModel(
      id: 'd0f092e2', name: 'View 4', groupId: '',
      kind: StepKind.viewStep,
      rectangle: _rect(5, 6),
    ));
    links.add(const LinkModel(inputStepId: 'd0f092e2', outputStepId: 'e79df6d6'));

    return WorkflowModel(
      id: '333e3ae3f7953437b6431c61f802eea5',
      name: 'test 22',
      projectId: 'martin-english-personal',
      steps: steps,
      links: links,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // RNAseq Data Connector — from stage.tercen.com
  // ID: 2cdf2d2d4f0adbadc5f95636b10e2cd9
  //
  // 11 steps, 3 source chains merging through 2 JoinSteps
  // ═══════════════════════════════════════════════════════════════════

  WorkflowModel _buildRnaseqWorkflow() {
    final steps = <StepModel>[];
    final links = <LinkModel>[];

    steps.add(StepModel(
      id: 'ts-gds5037',
      name: 'GDS5037_full.soft',
      groupId: '',
      kind: StepKind.tableStep,
    ));

    steps.add(StepModel(
      id: 'ds-csv-import-1',
      name: 'CSV Import',
      groupId: '',
      kind: StepKind.dataStep,
    ));
    links.add(const LinkModel(
      inputStepId: 'ds-csv-import-1',
      outputStepId: 'ts-gds5037',
    ));

    steps.add(StepModel(
      id: 'ms-gather',
      name: 'Gather',
      groupId: '',
      kind: StepKind.meltStep,
    ));
    links.add(const LinkModel(
      inputStepId: 'ms-gather',
      outputStepId: 'ds-csv-import-1',
    ));

    steps.add(StepModel(
      id: 'ds-median',
      name: 'Median Expression Per Gene',
      groupId: '',
      kind: StepKind.dataStep,
    ));
    links.add(const LinkModel(
      inputStepId: 'ds-median',
      outputStepId: 'ms-gather',
    ));

    steps.add(StepModel(
      id: 'ts-metadata',
      name: 'Sample_Metadata.csv',
      groupId: '',
      kind: StepKind.tableStep,
    ));

    steps.add(StepModel(
      id: 'ds-csv-import-2',
      name: 'CSV Import',
      groupId: '',
      kind: StepKind.dataStep,
    ));
    links.add(const LinkModel(
      inputStepId: 'ds-csv-import-2',
      outputStepId: 'ts-metadata',
    ));

    steps.add(StepModel(
      id: 'js-join-1',
      name: 'Join',
      groupId: '',
      kind: StepKind.joinStep,
    ));
    links.add(const LinkModel(
      inputStepId: 'js-join-1',
      outputStepId: 'ds-median',
    ));
    links.add(const LinkModel(
      inputStepId: 'js-join-1',
      outputStepId: 'ds-csv-import-2',
    ));

    steps.add(StepModel(
      id: 'ts-hallmark',
      name: 'hallmark_pathways.gmt',
      groupId: '',
      kind: StepKind.tableStep,
    ));

    steps.add(StepModel(
      id: 'ds-parse-gmt',
      name: 'Parse GMT Hallmark',
      groupId: '',
      kind: StepKind.dataStep,
    ));
    links.add(const LinkModel(
      inputStepId: 'ds-parse-gmt',
      outputStepId: 'ts-hallmark',
    ));

    steps.add(StepModel(
      id: 'js-join-2',
      name: 'Join',
      groupId: '',
      kind: StepKind.joinStep,
    ));
    links.add(const LinkModel(
      inputStepId: 'js-join-2',
      outputStepId: 'js-join-1',
    ));
    links.add(const LinkModel(
      inputStepId: 'js-join-2',
      outputStepId: 'ds-parse-gmt',
    ));

    steps.add(StepModel(
      id: 'os-output',
      name: 'Output',
      groupId: '',
      kind: StepKind.outStep,
    ));
    links.add(const LinkModel(
      inputStepId: 'os-output',
      outputStepId: 'js-join-2',
    ));

    return WorkflowModel(
      id: '2cdf2d2d4f0adbadc5f95636b10e2cd9',
      name: 'RNAseq Data Connector',
      projectId: '2cdf2d2d4f0adbadc5f95636b10e6b08',
      steps: steps,
      links: links,
    );
  }
}
