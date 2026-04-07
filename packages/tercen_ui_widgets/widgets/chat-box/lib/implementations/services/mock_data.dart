import '../../domain/models/chat_message.dart';
import '../../domain/models/chat_session.dart';
import '../../domain/models/focus_context.dart';

/// Static mock data for the Chat Box widget.
///
/// Provides 3 canned conversations per the spec:
///   1. Workflow setup (YAML code blocks, tables, numbered lists)
///   2. Data import help (bullet lists, JSON code blocks, tables)
///   3. Error troubleshooting (block quotes, headings, Python code)
class MockData {
  MockData._();

  /// Default focus context: Flow Immunophenotyping workflow.
  static FocusContext get defaultFocusContext => const FocusContext(
        sourceWindow: 'Workflow Viewer',
        nodeId: 'wf-001',
        nodeType: 'Workflow',
        nodeName: 'Flow Immunophenotyping',
        additionalContext: {
          'projectId': 'proj-immuno-001',
          'projectPath': '/Immunophenotyping Study',
        },
      );

  static List<ChatSession> buildSessions() {
    final now = DateTime.now();
    return [
      _buildSession1(now),
      _buildSession2(now),
      _buildSession3(now),
    ];
  }

  /// Session 1: "Workflow setup"
  static ChatSession _buildSession1(DateTime now) {
    final base = now.subtract(const Duration(hours: 2));
    return ChatSession(
      id: 'session-1',
      title: 'How do I create a flow cytometry analysis workflow?',
      createdAt: base,
      lastMessageAt: base.add(const Duration(minutes: 5)),
      messages: [
        ChatMessage(
          id: 'msg-1-1',
          role: MessageRole.user,
          content:
              'How do I create a flow cytometry analysis workflow?',
          timestamp: base,
        ),
        ChatMessage(
          id: 'msg-1-2',
          role: MessageRole.assistant,
          content: '''I can help you set up a flow cytometry analysis pipeline. Based on your **Flow Immunophenotyping** project, here is a recommended workflow structure:

```yaml
workflow:
  name: Flow Cytometry Analysis
  steps:
    - type: ImportStep
      operator: FCS Import
      description: Import raw FCS files

    - type: DataStep
      operator: Compensation
      description: Apply compensation matrix

    - type: DataStep
      operator: Transformation
      parameters:
        method: arcsinh
        cofactor: 150

    - type: DataStep
      operator: PhenoGraph
      description: Unsupervised clustering
```

This gives you a four-step pipeline from raw data to clusters. Would you like me to create this workflow?''',
          timestamp: base.add(const Duration(seconds: 30)),
        ),
        ChatMessage(
          id: 'msg-1-3',
          role: MessageRole.user,
          content:
              'Yes, and can you add a PhenoGraph clustering step with the right parameters?',
          timestamp: base.add(const Duration(minutes: 2)),
        ),
        ChatMessage(
          id: 'msg-1-4',
          role: MessageRole.assistant,
          content:
              '''Done! I have added the PhenoGraph clustering step. Here is what was configured:

1. **Select the input channels** -- the step will use all compensated and transformed markers
2. **Set the k parameter** -- this controls neighbourhood size for graph construction
3. **Choose the distance metric** -- cosine similarity works best for cytometry data

Here is the step configuration in detail:

```dart
final phenographStep = DataStep(
  operator: 'PhenoGraph',
  parameters: {
    'k': 30,
    'metric': 'cosine',
    'resolution': 1.0,
    'seed': 42,
  },
  inputs: ['Transformation.output'],
  outputs: ['clusters', 'graph'],
);
```

And a comparison of common parameter choices:

| Parameter | Default | Range | Recommendation |
|-----------|---------|-------|----------------|
| k | 30 | 10-100 | 30 for standard panels, 15 for small panels |
| metric | cosine | cosine, euclidean | cosine for cytometry |
| resolution | 1.0 | 0.1-2.0 | Higher values = more clusters |
| seed | 42 | any integer | Set for reproducibility |

The step is now visible in the Workflow Viewer. You can click on it to inspect or modify the parameters.''',
          timestamp: base.add(const Duration(minutes: 2, seconds: 30)),
        ),
      ],
    );
  }

  /// Session 2: "Data import help"
  static ChatSession _buildSession2(DateTime now) {
    final base = now.subtract(const Duration(hours: 5));
    return ChatSession(
      id: 'session-2',
      title: 'How do I upload FCS files to my project?',
      createdAt: base,
      lastMessageAt: base.add(const Duration(minutes: 8)),
      messages: [
        ChatMessage(
          id: 'msg-2-1',
          role: MessageRole.user,
          content: 'How do I upload FCS files to my project?',
          timestamp: base,
        ),
        ChatMessage(
          id: 'msg-2-2',
          role: MessageRole.assistant,
          content:
              '''To upload FCS files to your project, follow these steps:

- **Open the File Navigator** (Window 1) and navigate to your project folder
- Click the **Upload** button in the toolbar
- Select your FCS files from the file picker -- you can select multiple files at once
- The files will be uploaded to the current directory

A few important notes:

- Supported formats: `.fcs` (FCS 3.0 and 3.1), `.csv`, `.tsv`
- Maximum file size: **500 MB** per file
- Files are uploaded to the path shown in the navigator breadcrumb
- After upload, the files appear in the tree at `~/projects/Immunophenotyping Study/data/`

You can verify the upload by checking that the files appear with the correct size in the File Navigator. The `fcs` file icon will show in green once the file is indexed.''',
          timestamp: base.add(const Duration(seconds: 25)),
        ),
        ChatMessage(
          id: 'msg-2-3',
          role: MessageRole.user,
          content:
              'My FCS files have non-standard column names. How do I map them to the Tercen schema?',
          timestamp: base.add(const Duration(minutes: 5)),
        ),
        ChatMessage(
          id: 'msg-2-4',
          role: MessageRole.assistant,
          content:
              '''Column mapping is handled during the import step. Here is how your columns would map:

| Source Column (FCS) | Tercen Schema Column | Type |
|---------------------|---------------------|------|
| FSC-A | forward_scatter_area | numeric |
| FSC-H | forward_scatter_height | numeric |
| SSC-A | side_scatter_area | numeric |
| CD3 (APC) | cd3_apc | marker |
| CD4 (FITC) | cd4_fitc | marker |
| CD8 (PE) | cd8_pe | marker |
| CD19 (PerCP) | cd19_percp | marker |
| Time | acquisition_time | numeric |

To set this mapping, configure the import step with:

```json
{
  "import": {
    "format": "fcs",
    "version": "3.1",
    "column_mapping": {
      "FSC-A": "forward_scatter_area",
      "FSC-H": "forward_scatter_height",
      "SSC-A": "side_scatter_area",
      "CD3 (APC)": "cd3_apc",
      "CD4 (FITC)": "cd4_fitc",
      "CD8 (PE)": "cd8_pe",
      "CD19 (PerCP)": "cd19_percp",
      "Time": "acquisition_time"
    },
    "skip_unmapped": true
  }
}
```

Once configured, all subsequent FCS files with the same panel will use this mapping automatically.''',
          timestamp: base.add(const Duration(minutes: 5, seconds: 30)),
        ),
      ],
    );
  }

  /// Session 3: "Error troubleshooting"
  static ChatSession _buildSession3(DateTime now) {
    final base = now.subtract(const Duration(days: 1));
    return ChatSession(
      id: 'session-3',
      title: 'My PhenoGraph step failed with an error',
      createdAt: base,
      lastMessageAt: base.add(const Duration(minutes: 12)),
      messages: [
        ChatMessage(
          id: 'msg-3-1',
          role: MessageRole.user,
          content:
              'My PhenoGraph step failed with an error. The log says "ValueError: n_samples=5 should be >= n_neighbors=30"',
          timestamp: base,
        ),
        ChatMessage(
          id: 'msg-3-2',
          role: MessageRole.assistant,
          content:
              '''I can see the issue. Here is the error from the log:

> ValueError: n_samples=5 should be >= n_neighbors=30

### Diagnosis

This error occurs when the **k parameter** (n_neighbors) is larger than the number of data points in your input.

#### Root Cause

Your input data has only **5 samples**, but PhenoGraph is configured with `k=30`, which requires at least 30 samples to build the nearest-neighbour graph.

#### Possible causes

- The upstream **gating step** filtered out too many events
- The **compensation step** produced NaN values that were dropped
- The input file has fewer events than expected

### Fix

Reduce the k parameter to be smaller than your sample count. Here is a corrected configuration:

```python
# Fix: set k to be less than n_samples
import phenograph

# Check sample count first
n_samples = data.shape[0]
k = min(30, n_samples - 1)  # Ensure k < n_samples

if n_samples < 10:
    print(f"Warning: only {n_samples} samples. Consider checking upstream steps.")

communities, graph, Q = phenograph.cluster(
    data,
    k=k,
    primary_metric='cosine',
    seed=42
)
```

Alternatively, check why you only have 5 samples -- that is unusually low for cytometry data. I would recommend inspecting the **Compensation** step output first.''',
          timestamp: base.add(const Duration(seconds: 40)),
        ),
        ChatMessage(
          id: 'msg-3-3',
          role: MessageRole.user,
          content:
              'You were right, the compensation step was dropping rows with NaN. I fixed the input and now it runs with 50,000 events. Thanks!',
          timestamp: base.add(const Duration(minutes: 10)),
        ),
        ChatMessage(
          id: 'msg-3-4',
          role: MessageRole.assistant,
          content:
              '''That is great to hear! 50,000 events is a solid sample size for PhenoGraph clustering.

With that many events and `k=30`, you should expect the clustering to complete in about 30-60 seconds. The results will be available in the **Workflow Viewer** once the step finishes.

If you want to visualise the clusters, consider adding a **UMAP** step after PhenoGraph -- it will give you a 2D projection coloured by cluster assignment.''',
          timestamp: base.add(const Duration(minutes: 10, seconds: 20)),
        ),
      ],
    );
  }
}
