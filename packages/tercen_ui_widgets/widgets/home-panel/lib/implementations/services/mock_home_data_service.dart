import '../../domain/models/home_models.dart';
import '../../domain/services/home_data_service.dart';

/// Mock implementation of HomeDataService for Phase 2 standalone development.
class MockHomeDataService implements HomeDataService {
  static const List<FeaturedApp> _allApps = [
    FeaturedApp(appId: 'app-pca', name: 'PCA Analysis', description: 'Principal component analysis for dimensionality reduction'),
    FeaturedApp(appId: 'app-flow', name: 'Flow Cytometry', description: 'Automated flow cytometry gating and analysis'),
    FeaturedApp(appId: 'app-boxplot', name: 'Boxplot Viewer', description: 'Interactive boxplot visualization'),
    FeaturedApp(appId: 'app-heatmap', name: 'Heatmap Generator', description: 'Clustered heatmap visualization'),
    FeaturedApp(appId: 'app-meancv', name: 'Mean & CV Calculator', description: 'Compute mean and coefficient of variation'),
    FeaturedApp(appId: 'app-imgov', name: 'Image Overview', description: 'Browse and annotate image datasets'),
    FeaturedApp(appId: 'app-scatter', name: 'Scatter Plot', description: 'Interactive scatter plot with brushing and linking'),
    FeaturedApp(appId: 'app-volcano', name: 'Volcano Plot', description: 'Differential expression volcano plot'),
    FeaturedApp(appId: 'app-histogram', name: 'Histogram', description: 'Distribution histogram with density overlay'),
    FeaturedApp(appId: 'app-tsne', name: 't-SNE', description: 'T-distributed stochastic neighbor embedding'),
    FeaturedApp(appId: 'app-umap', name: 'UMAP', description: 'Uniform manifold approximation and projection'),
    FeaturedApp(appId: 'app-violin', name: 'Violin Plot', description: 'Violin plot with density distribution'),
    FeaturedApp(appId: 'app-kmeans', name: 'K-Means Clustering', description: 'Unsupervised k-means clustering'),
    FeaturedApp(appId: 'app-corr', name: 'Correlation Matrix', description: 'Pairwise correlation heatmap'),
    FeaturedApp(appId: 'app-survival', name: 'Survival Analysis', description: 'Kaplan-Meier survival curves'),
    FeaturedApp(appId: 'app-deseq', name: 'DESeq2', description: 'Differential expression analysis for RNA-seq'),
    FeaturedApp(appId: 'app-enrichment', name: 'Pathway Enrichment', description: 'Gene set enrichment analysis'),
    FeaturedApp(appId: 'app-qc', name: 'QC Dashboard', description: 'Quality control metrics dashboard'),
    FeaturedApp(appId: 'app-normalization', name: 'Normalization', description: 'Data normalization and scaling methods'),
    FeaturedApp(appId: 'app-impute', name: 'Missing Value Imputation', description: 'Impute missing values using various methods'),
    FeaturedApp(appId: 'app-batch', name: 'Batch Correction', description: 'Remove batch effects from multi-batch data'),
  ];

  static const List<RecentProject> _allProjects = [
    RecentProject(projectId: 'proj-immuno-v3', name: 'Immunophenotyping v3', owner: 'MartinLibrary', lastModified: '2 hours ago'),
    RecentProject(projectId: 'proj-pca', name: 'PCA Analysis', owner: 'MartinLibrary', lastModified: 'Yesterday'),
    RecentProject(projectId: 'proj-std-op', name: 'Standard Operator Test', owner: 'Team10Dec2025', lastModified: '3 days ago'),
    RecentProject(projectId: 'proj-crabs', name: 'Crabs Dataset', owner: 'Team10Dec2025', lastModified: '1 week ago'),
    RecentProject(projectId: 'proj-flow-pipeline', name: 'Flow Cytometry Pipeline', owner: 'MartinLibrary', lastModified: '2 weeks ago'),
    RecentProject(projectId: 'proj-rnaseq', name: 'RNA-seq Differential Expression', owner: 'MartinLibrary', lastModified: '2 weeks ago'),
    RecentProject(projectId: 'proj-proteomics', name: 'Proteomics LC-MS Analysis', owner: 'Team10Dec2025', lastModified: '3 weeks ago'),
    RecentProject(projectId: 'proj-metabolomics', name: 'Metabolomics Profiling', owner: 'MartinLibrary', lastModified: '3 weeks ago'),
    RecentProject(projectId: 'proj-single-cell', name: 'Single Cell RNA-seq', owner: 'Team10Dec2025', lastModified: '1 month ago'),
    RecentProject(projectId: 'proj-clinical', name: 'Clinical Trial Data', owner: 'MartinLibrary', lastModified: '1 month ago'),
    RecentProject(projectId: 'proj-microbiome', name: 'Microbiome 16S Analysis', owner: 'Team10Dec2025', lastModified: '1 month ago'),
    RecentProject(projectId: 'proj-spatial', name: 'Spatial Transcriptomics', owner: 'MartinLibrary', lastModified: '2 months ago'),
    RecentProject(projectId: 'proj-chip-seq', name: 'ChIP-seq Peak Calling', owner: 'Team10Dec2025', lastModified: '2 months ago'),
    RecentProject(projectId: 'proj-gwas', name: 'GWAS Summary Stats', owner: 'MartinLibrary', lastModified: '2 months ago'),
    RecentProject(projectId: 'proj-methylation', name: 'DNA Methylation Array', owner: 'Team10Dec2025', lastModified: '3 months ago'),
    RecentProject(projectId: 'proj-imaging', name: 'High-Content Imaging', owner: 'MartinLibrary', lastModified: '3 months ago'),
    RecentProject(projectId: 'proj-elisa', name: 'ELISA Plate Reader', owner: 'Team10Dec2025', lastModified: '3 months ago'),
    RecentProject(projectId: 'proj-western', name: 'Western Blot Quantification', owner: 'MartinLibrary', lastModified: '4 months ago'),
    RecentProject(projectId: 'proj-ngs-qc', name: 'NGS Quality Control', owner: 'Team10Dec2025', lastModified: '4 months ago'),
    RecentProject(projectId: 'proj-drug-screen', name: 'Drug Screening Assay', owner: 'MartinLibrary', lastModified: '5 months ago'),
    RecentProject(projectId: 'proj-cytof', name: 'CyTOF Mass Cytometry', owner: 'Team10Dec2025', lastModified: '5 months ago'),
  ];

  static const List<ActivityEvent> _allActivities = [
    ActivityEvent(id: 'act-1', type: 'create', objectName: 'Flow Immunophenotyping', resourceType: 'workflow', resourceId: 'wf-flow-immuno', date: '1 hour ago', team: 'MartinLibrary', user: 'Martin', projectName: 'Immunophenotyping v3', projectId: 'proj-immuno-v3'),
    ActivityEvent(id: 'act-2', type: 'update', objectName: 'Immunophenotyping v3', resourceType: 'project', resourceId: 'proj-immuno-v3', date: '2 hours ago', team: 'MartinLibrary', user: 'Martin', projectName: 'Immunophenotyping v3', projectId: 'proj-immuno-v3'),
    ActivityEvent(id: 'act-3', type: 'run', objectName: 'PhenoGraph Step', resourceType: 'task', resourceId: 'task-phenograph', date: '3 hours ago', team: 'MartinLibrary', user: 'Martin', projectName: 'Immunophenotyping v3', projectId: 'proj-immuno-v3'),
    ActivityEvent(id: 'act-4', type: 'complete', objectName: 'PCA Computation', resourceType: 'task', resourceId: 'task-pca', date: '4 hours ago', team: 'MartinLibrary', user: 'Martin', projectName: 'PCA Analysis', projectId: 'proj-pca'),
    ActivityEvent(id: 'act-5', type: 'create', objectName: 'crabs_data.csv', resourceType: 'file', resourceId: 'file-crabs-csv', date: 'Yesterday', team: 'Team10Dec2025', user: 'Alice', projectName: 'Crabs Dataset', projectId: 'proj-crabs'),
    ActivityEvent(id: 'act-6', type: 'update', objectName: 'Crabs Workflow', resourceType: 'workflow', resourceId: 'wf-crabs', date: 'Yesterday', team: 'Team10Dec2025', user: 'Bob', projectName: 'Crabs Dataset', projectId: 'proj-crabs'),
    ActivityEvent(id: 'act-7', type: 'delete', objectName: 'old_report.md', resourceType: 'file', resourceId: 'file-old-report', date: '2 days ago', team: 'MartinLibrary', user: 'Martin', projectName: 'Immunophenotyping v3', projectId: 'proj-immuno-v3'),
    ActivityEvent(id: 'act-8', type: 'create', objectName: 'New Experiment', resourceType: 'project', resourceId: 'proj-new-exp', date: '3 days ago', team: 'Team10Dec2025', user: 'Alice', projectName: 'New Experiment', projectId: 'proj-new-exp'),
    ActivityEvent(id: 'act-9', type: 'run', objectName: 'Normalization Step', resourceType: 'task', resourceId: 'task-norm', date: '3 days ago', team: 'MartinLibrary', user: 'Martin', projectName: 'RNA-seq Differential Expression', projectId: 'proj-rnaseq'),
    ActivityEvent(id: 'act-10', type: 'complete', objectName: 'Batch Correction', resourceType: 'task', resourceId: 'task-batch', date: '4 days ago', team: 'Team10Dec2025', user: 'Bob', projectName: 'Proteomics LC-MS Analysis', projectId: 'proj-proteomics'),
    ActivityEvent(id: 'act-11', type: 'update', objectName: 'RNA-seq Pipeline', resourceType: 'workflow', resourceId: 'wf-rnaseq', date: '4 days ago', team: 'MartinLibrary', user: 'Martin', projectName: 'RNA-seq Differential Expression', projectId: 'proj-rnaseq'),
    ActivityEvent(id: 'act-12', type: 'create', objectName: 'sample_metadata.csv', resourceType: 'file', resourceId: 'file-metadata', date: '5 days ago', team: 'Team10Dec2025', user: 'Alice', projectName: 'Crabs Dataset', projectId: 'proj-crabs'),
    ActivityEvent(id: 'act-13', type: 'run', objectName: 'DESeq2 Analysis', resourceType: 'task', resourceId: 'task-deseq', date: '5 days ago', team: 'MartinLibrary', user: 'Martin', projectName: 'RNA-seq Differential Expression', projectId: 'proj-rnaseq'),
    ActivityEvent(id: 'act-14', type: 'delete', objectName: 'temp_results.csv', resourceType: 'file', resourceId: 'file-temp', date: '6 days ago', team: 'Team10Dec2025', user: 'Bob', projectName: 'Proteomics LC-MS Analysis', projectId: 'proj-proteomics'),
    ActivityEvent(id: 'act-15', type: 'create', objectName: 'QC Report Workflow', resourceType: 'workflow', resourceId: 'wf-qc', date: '1 week ago', team: 'MartinLibrary', user: 'Martin', projectName: 'Metabolomics Profiling', projectId: 'proj-metabolomics'),
    ActivityEvent(id: 'act-16', type: 'complete', objectName: 'K-Means Clustering', resourceType: 'task', resourceId: 'task-kmeans', date: '1 week ago', team: 'Team10Dec2025', user: 'Alice', projectName: 'Single Cell RNA-seq', projectId: 'proj-single-cell'),
    ActivityEvent(id: 'act-17', type: 'update', objectName: 'Proteomics Pipeline', resourceType: 'workflow', resourceId: 'wf-prot', date: '1 week ago', team: 'MartinLibrary', user: 'Martin', projectName: 'Proteomics LC-MS Analysis', projectId: 'proj-proteomics'),
    ActivityEvent(id: 'act-18', type: 'run', objectName: 'UMAP Embedding', resourceType: 'task', resourceId: 'task-umap', date: '2 weeks ago', team: 'Team10Dec2025', user: 'Bob', projectName: 'Single Cell RNA-seq', projectId: 'proj-single-cell'),
    ActivityEvent(id: 'act-19', type: 'create', objectName: 'Clinical Outcomes', resourceType: 'project', resourceId: 'proj-outcomes', date: '2 weeks ago', team: 'MartinLibrary', user: 'Martin', projectName: 'Clinical Trial Data', projectId: 'proj-clinical'),
    ActivityEvent(id: 'act-20', type: 'complete', objectName: 'Survival Analysis', resourceType: 'task', resourceId: 'task-survival', date: '2 weeks ago', team: 'Team10Dec2025', user: 'Alice', projectName: 'Clinical Trial Data', projectId: 'proj-clinical'),
    ActivityEvent(id: 'act-21', type: 'update', objectName: 'Microbiome 16S', resourceType: 'workflow', resourceId: 'wf-16s', date: '3 weeks ago', team: 'MartinLibrary', user: 'Martin', projectName: 'Microbiome 16S Analysis', projectId: 'proj-microbiome'),
  ];

  @override
  Future<HomeUser> getCurrentUser() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const HomeUser(
      userId: 'martin.english',
      displayName: 'Martin',
      teams: ['MartinLibrary', 'Team10Dec2025'],
    );
  }

  @override
  Future<List<RecentProject>> getRecentProjects(String userId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _allProjects;
  }

  @override
  Future<List<RecentProject>> searchProjects(String query,
      {int limit = 10}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final lowerQuery = query.toLowerCase();
    return _allProjects
        .where((p) =>
            p.name.toLowerCase().contains(lowerQuery) ||
            p.owner.toLowerCase().contains(lowerQuery))
        .take(limit)
        .toList();
  }

  @override
  Future<List<ActivityEvent>> getRecentActivity(List<String> teamIds) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _allActivities;
  }

  @override
  Future<List<FeaturedApp>> getFeaturedApps(
      {int offset = 0, int limit = 6}) async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (offset >= _allApps.length) return [];
    final end =
        (offset + limit) > _allApps.length ? _allApps.length : offset + limit;
    return _allApps.sublist(offset, end);
  }

  @override
  List<HelpLink> getHelpLinks() {
    return const [
      HelpLink(label: 'Documentation', url: 'https://docs.tercen.com'),
      HelpLink(label: 'Getting Started', url: 'https://docs.tercen.com/getting-started'),
      HelpLink(label: 'Tutorials', url: 'https://docs.tercen.com/tutorials'),
      HelpLink(label: 'Community', url: 'https://community.tercen.com'),
    ];
  }
}
