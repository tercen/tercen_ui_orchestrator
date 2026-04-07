import '../../domain/models/tree_node.dart';
import '../../domain/services/data_service.dart';

/// Mock implementation that returns a realistic navigator tree.
class MockDataService implements DataService {
  @override
  Future<List<TreeNode>> fetchTree() async {
    await Future.delayed(const Duration(milliseconds: 400));

    return [
      // Personal team — auto-expanded
      TreeNode(
        id: 'team-personal',
        name: 'Personal',
        nodeType: NodeType.team,
        isPersonalTeam: true,
        children: [
          TreeNode(
            id: 'proj-immuno',
            name: 'Immunophenotyping',
            nodeType: NodeType.project,
            parentId: 'team-personal',
            isPublic: true,
            githubUrl: 'https://github.com/tercen/tercen_ui_widgets',
            gitVersion: 'v2.3',
            children: [
              TreeNode(
                id: 'file-readme',
                name: 'README.md',
                nodeType: NodeType.file,
                parentId: 'proj-immuno',
                isLeaf: true,
                fileCategory: FileCategory.generic,
              ),
              TreeNode(
                id: 'file-omip',
                name: 'omip69_1k_donor.zip',
                nodeType: NodeType.file,
                parentId: 'proj-immuno',
                isLeaf: true,
                fileCategory: FileCategory.zip,
              ),
              TreeNode(
                id: 'ds-sample',
                name: 'Sample_annotation.csv',
                nodeType: NodeType.dataset,
                parentId: 'proj-immuno',
                isLeaf: true,
              ),
              TreeNode(
                id: 'ds-channels',
                name: 'OMIP-069 - Channel Descriptions',
                nodeType: NodeType.dataset,
                parentId: 'proj-immuno',
                isLeaf: true,
              ),
              TreeNode(
                id: 'wf-flow',
                name: 'Flow Immunophenotyping',
                nodeType: NodeType.workflow,
                parentId: 'proj-immuno',
                isLeaf: true,
              ),
              TreeNode(
                id: 'folder-reports',
                name: 'reports',
                nodeType: NodeType.folder,
                parentId: 'proj-immuno',
                children: [
                  TreeNode(
                    id: 'file-summary',
                    name: 'analysis_summary.md',
                    nodeType: NodeType.file,
                    parentId: 'folder-reports',
                    isLeaf: true,
                    fileCategory: FileCategory.generic,
                  ),
                  TreeNode(
                    id: 'file-heatmap',
                    name: 'heatmap.png',
                    nodeType: NodeType.file,
                    parentId: 'folder-reports',
                    isLeaf: true,
                    fileCategory: FileCategory.image,
                  ),
                  TreeNode(
                    id: 'file-export',
                    name: 'results_export.csv',
                    nodeType: NodeType.file,
                    parentId: 'folder-reports',
                    isLeaf: true,
                    fileCategory: FileCategory.generic,
                  ),
                ],
              ),
            ],
          ),
          TreeNode(
            id: 'proj-pca',
            name: 'PCA Analysis',
            nodeType: NodeType.project,
            parentId: 'team-personal',
            isPublic: true,
            githubUrl: 'https://github.com/tercen/tercen_ui_widgets',
            gitVersion: 'v1.0',
            children: [
              TreeNode(
                id: 'file-pca-data',
                name: 'iris_dataset.csv',
                nodeType: NodeType.file,
                parentId: 'proj-pca',
                isLeaf: true,
                fileCategory: FileCategory.generic,
              ),
              TreeNode(
                id: 'ds-pca-table',
                name: 'PCA Results',
                nodeType: NodeType.dataset,
                parentId: 'proj-pca',
                isLeaf: true,
              ),
              TreeNode(
                id: 'wf-pca',
                name: 'PCA Pipeline',
                nodeType: NodeType.workflow,
                parentId: 'proj-pca',
                isLeaf: true,
              ),
              TreeNode(
                id: 'file-pca-plot',
                name: 'scree_plot.png',
                nodeType: NodeType.file,
                parentId: 'proj-pca',
                isLeaf: true,
                fileCategory: FileCategory.image,
              ),
            ],
          ),
          TreeNode(
            id: 'proj-preproc',
            name: 'flow_preprocessing',
            nodeType: NodeType.project,
            parentId: 'team-personal',
            githubUrl: 'https://github.com/tercen/tercen_ui_widgets',
            gitVersion: 'v2.3',
            children: [
              TreeNode(
                id: 'folder-data',
                name: 'data',
                nodeType: NodeType.folder,
                parentId: 'proj-preproc',
                children: [
                  TreeNode(
                    id: 'file-fcs1',
                    name: 'sample_001.fcs',
                    nodeType: NodeType.file,
                    parentId: 'folder-data',
                    isLeaf: true,
                    fileCategory: FileCategory.generic,
                  ),
                  TreeNode(
                    id: 'file-fcs2',
                    name: 'sample_002.fcs',
                    nodeType: NodeType.file,
                    parentId: 'folder-data',
                    isLeaf: true,
                    fileCategory: FileCategory.generic,
                  ),
                ],
              ),
              TreeNode(
                id: 'file-preproc-readme',
                name: 'README.md',
                nodeType: NodeType.file,
                parentId: 'proj-preproc',
                isLeaf: true,
                fileCategory: FileCategory.generic,
              ),
              TreeNode(
                id: 'wf-preproc',
                name: 'Preprocessing Pipeline',
                nodeType: NodeType.workflow,
                parentId: 'proj-preproc',
                isLeaf: true,
              ),
            ],
          ),
        ],
      ),
      // Other teams — collapsed
      TreeNode(
        id: 'team-alpha',
        name: 'MartinLibrary',
        nodeType: NodeType.team,
        children: [
          TreeNode(
            id: 'proj-shared1',
            name: 'Shared Markers',
            nodeType: NodeType.project,
            parentId: 'team-alpha',
            isPublic: true,
            children: [
              TreeNode(
                id: 'ds-markers',
                name: 'Marker Panel v3',
                nodeType: NodeType.dataset,
                parentId: 'proj-shared1',
                isLeaf: true,
              ),
              TreeNode(
                id: 'wf-markers',
                name: 'Marker Analysis',
                nodeType: NodeType.workflow,
                parentId: 'proj-shared1',
                isLeaf: true,
              ),
            ],
          ),
          TreeNode(
            id: 'proj-shared2',
            name: 'Reference Data',
            nodeType: NodeType.project,
            parentId: 'team-alpha',
            children: [
              TreeNode(
                id: 'file-ref1',
                name: 'human_cd_markers.csv',
                nodeType: NodeType.file,
                parentId: 'proj-shared2',
                isLeaf: true,
                fileCategory: FileCategory.generic,
              ),
            ],
          ),
        ],
      ),
      TreeNode(
        id: 'team-beta',
        name: 'MyNewTeam',
        nodeType: NodeType.team,
        children: [
          TreeNode(
            id: 'proj-beta1',
            name: 'Experiment Q4',
            nodeType: NodeType.project,
            parentId: 'team-beta',
            children: [
              TreeNode(
                id: 'file-beta-zip',
                name: 'raw_data_bundle.zip',
                nodeType: NodeType.file,
                parentId: 'proj-beta1',
                isLeaf: true,
                fileCategory: FileCategory.zip,
              ),
              TreeNode(
                id: 'ds-beta-results',
                name: 'Experiment Results',
                nodeType: NodeType.dataset,
                parentId: 'proj-beta1',
                isLeaf: true,
              ),
            ],
          ),
        ],
      ),
      TreeNode(
        id: 'team-gamma',
        name: 'Team10Dec2025',
        nodeType: NodeType.team,
        children: [
          TreeNode(
            id: 'proj-gamma1',
            name: 'Audit Review',
            nodeType: NodeType.project,
            parentId: 'team-gamma',
            children: [
              TreeNode(
                id: 'file-gamma-img',
                name: 'overview_chart.png',
                nodeType: NodeType.file,
                parentId: 'proj-gamma1',
                isLeaf: true,
                fileCategory: FileCategory.image,
              ),
              TreeNode(
                id: 'wf-gamma-audit',
                name: 'Audit Workflow',
                nodeType: NodeType.workflow,
                parentId: 'proj-gamma1',
                isLeaf: true,
              ),
            ],
          ),
        ],
      ),
    ];
  }

  @override
  Future<void> uploadFile(String targetNodeId, String fileName) async {
    // Simulate upload delay
    await Future.delayed(const Duration(seconds: 2));
  }
}
