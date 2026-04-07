# Chat Box — Functional Specification

**Version:** 1.0
**Last Updated:** 2026-03-12
**Reference:** Original specification
**Window:** 2 (Chat)
**App Type:** skeleton-window (Feature Window for Tercen Frame)
**Status:** Ready for review

---

## 1. Purpose

The Chat Box is the primary LLM interaction surface in the Tercen platform. It provides a conversational interface where users interact with Claude to perform platform operations, ask questions about their data, and receive guidance on workflows and analysis.

The chat exists for **three user actions**:

1. **Ask** -- type a question or instruction for the LLM
2. **Read** -- review the LLM's response, including rich markdown with syntax-highlighted code blocks
3. **Manage sessions** -- create new conversations and switch between past sessions

All platform operations requested through chat (create steps, open files, modify workflows) are executed by the LLM via Tercen MCP tools. The Chat Box emits action intents on the EventBus; the Frame orchestrator routes them to the appropriate windows and services.

---

## 2. Context -- Where This Fits

### 2.1 Product context

The Tercen LLM platform has eight feature windows:

| # | Window | Role |
|---|--------|------|
| 0 | Home Page | Entry point and project navigation |
| 1 | File Navigator | Browse hierarchy, upload, set focus, open viewers |
| **2** | **Chat** | **This spec -- primary LLM interaction surface** |
| 3 | Workflow Viewer | Pipeline visualisation, step focus, execution control |
| 4 | Document Viewer/Editor | Markdown, SVG, reports |
| 5 | Data Viewer/Annotator | Tercen data tables |
| 6 | Visualisation Viewer/Annotator | Plots and images with markup |
| 7 | Audit Trail | Logs and history |

### 2.2 Three user types

| User | Relationship with the chat |
|------|---------------------------------|
| **Scientist** | Primary user. Asks the LLM to build workflows, configure operators, explain results, and troubleshoot errors. Relies on rich markdown responses with code examples. |
| **Bioinformatician** | Uses chat to script complex pipelines, inspect operator configurations, and request bulk operations. Relies heavily on code block rendering. |
| **Auditor** | Reviews chat history to understand what operations the LLM performed and why. Primarily reads past sessions. |

---

## 3. Architecture -- skeleton-window Conformance

This window conforms to the **skeleton-window** pattern from `skeletons/window/`.

### 3.1 App type

**Type 1 Feature Window** -- rendered inside the Tercen Frame. The Frame provides tabs above this window. The chat communicates with the Frame and other windows exclusively via the **EventBus**.

### 3.2 Four body states

The window MUST implement all four body states per the skeleton-window pattern:

| State | When | Display |
|-------|------|---------|
| **Loading** | Connecting to the LLM API or loading a session | Centred spinner + "Loading chat..." |
| **Empty** | No conversation yet (fresh session, no messages) | Centred icon + "Start a conversation" + helper text "Ask a question or give an instruction" |
| **Active** | Conversation has at least one message | Toolbar + Message List + Input Area |
| **Error** | LLM API connection failed or session could not be loaded | Centred error icon + message + "Retry" button |

### 3.3 Layout

Toolbar (fixed height) at top, Message List (scrollable, fills remaining space) in the middle, Input Area (pinned to bottom) below.

```text
+------------------------------------------+
| Toolbar                                  |
+------------------------------------------+
|                                          |
| Message List (scrollable Y)             |
|                                          |
+------------------------------------------+
| Input Area (pinned bottom)               |
+------------------------------------------+
```

### 3.4 State

The widget tracks the following state:

| State | Purpose |
|-------|---------|
| Current session | The active chat session (ID, title, messages) |
| Message list | Ordered list of messages in the current session |
| Sessions list | All available chat sessions for the session switcher |
| Input text | Current text in the input field |
| Is sending | Whether a message is currently being sent to the LLM (waiting for response) |
| Focus context | The most recent focus context received from other windows via EventBus |
| Window state | Current body state (loading, empty, active, error) |
| Error message | Detail text when in the error state |

### 3.5 Theming

- All UI chrome must be theme-aware (light and dark modes)
- Use only the shared design token system -- no hardcoded colours, font sizes, spacing, or stroke widths
- Markdown rendering must respect theme colours for code blocks, inline code, links, and headings

### 3.6 Window identity

| Property | Value |
|----------|-------|
| Tab label | "Chat" |
| Tab icon | Small coloured square per feature-window-base-spec |

---

## 4. Message Model

### 4.1 Message structure

Each message in a conversation has the following properties:

- `id` -- unique message identifier
- `role` -- either "user" or "assistant"
- `content` -- the message text (plain text for user messages, markdown for assistant messages)
- `timestamp` -- when the message was created

### 4.2 Session structure

A chat session groups a sequence of messages into a named conversation:

- `id` -- unique session identifier
- `title` -- display title (derived from the first user message, or "New Chat" if empty)
- `messages` -- ordered list of messages
- `createdAt` -- when the session was created
- `lastMessageAt` -- timestamp of the most recent message

---

## 5. Toolbar

Fixed height. Follows the skeleton-window toolbar pattern.

### 5.1 Buttons and controls

| Control | Position | Icon (FA6) | Tooltip | Active when | Action |
|---------|----------|------------|---------|-------------|--------|
| **New Chat** | Left | `plus` | "New Chat" | Always | Creates a new empty session and switches to it |
| **History** | Trailing | `clockRotateLeft` | "Chat History" | Always | Opens a popover/dropdown listing past sessions |

### 5.2 History popover

The History control opens a popover or dropdown that displays the list of past chat sessions:

- Sessions are listed in reverse chronological order (most recent first)
- Each entry shows the session title and a relative timestamp (e.g. "2 hours ago", "Yesterday")
- Session titles use text overflow with ellipsis (single line)
- Clicking a session entry switches to that session and closes the popover
- The currently active session is visually distinguished (highlighted background)
- The popover is scrollable if the session list exceeds the available height

### 5.3 Toolbar layout

```text
[New Chat]  ............................  [History]
 (left)              (Spacer)            (trailing)
```

---

## 6. Message List

The message list is a vertically scrollable area that displays all messages in the current session in chronological order (oldest at top, newest at bottom).

### 6.1 Auto-scroll behaviour

- When a new message is added (user or assistant), the list auto-scrolls to the bottom to show the latest message
- If the user has manually scrolled up to review earlier messages, auto-scroll is suppressed until the user scrolls back to the bottom

### 6.2 User messages

- Visually distinct from assistant messages (different background colour using theme tokens)
- Display the message content as plain text
- Right-aligned or styled with a distinct background to differentiate from assistant messages
- Timestamp displayed in muted text below the message content

### 6.3 Assistant messages

- Left-aligned or full-width with a distinct background colour from user messages
- Content rendered as rich markdown (see Section 7)
- Timestamp displayed in muted text below the message content

### 6.4 Sending indicator

While a message is being sent and the LLM response is pending (`isSending` = true):

- The user's sent message appears immediately in the list
- A loading indicator (spinner or animated dots) appears below the user message in the assistant message position
- The input area is disabled (see Section 8.3)

---

## 7. Markdown Rendering

Assistant messages render their content as rich markdown. The rendering must support:

### 7.1 Supported markdown elements

| Element | Rendering |
|---------|-----------|
| **Headings** (h1-h4) | Styled using AppTextStyles hierarchy (h1, h2, h3, body) |
| **Bold / italic** | Standard weight and style variations |
| **Inline code** | Monospace font with a subtle background tint (theme-aware) |
| **Fenced code blocks** | Syntax-highlighted block with language label, monospace font, distinct background (theme-aware) |
| **Bullet lists** | Standard indented list with bullet markers |
| **Numbered lists** | Standard indented list with number markers |
| **Links** | Tappable, styled in primary colour |
| **Block quotes** | Left border accent with indented text |
| **Tables** | Bordered table with header row styling |
| **Horizontal rules** | Subtle divider line |
| **Paragraphs** | Standard body text with appropriate line spacing |

### 7.2 Code block rendering

Fenced code blocks (triple backtick with optional language identifier) receive special treatment:

- Syntax highlighting appropriate to the declared language (e.g. `dart`, `python`, `json`, `yaml`, `r`)
- A language label displayed at the top of the block (when a language is specified)
- Distinct background colour from the surrounding message (theme-aware)
- Horizontal scrolling if a line exceeds the available width (no wrapping of code lines)
- Monospace font throughout the block

### 7.3 Theme integration

All markdown elements must use theme-aware colours:

- Code block backgrounds use a neutral tint that contrasts with the message background in both light and dark modes
- Link colours use the primary token
- Inline code backgrounds use a subtle neutral tint
- Heading colours follow the standard text colour tokens

---

## 8. Input Area

The input area is pinned to the bottom of the window body, below the message list.

### 8.1 Layout

```text
+------------------------------------------+
| [Multi-line text field          ] [Send] |
+------------------------------------------+
```

### 8.2 Text field

- Multi-line text input that grows vertically as the user types (up to a maximum height, then scrolls internally)
- Placeholder text: "Type a message..."
- Placeholder uses muted text colour
- Supports Enter to send (with Shift+Enter for new line)
- Standard body font

### 8.3 Send button

- Icon: `paperPlane` (FontAwesome 6)
- Tooltip: "Send"
- Enabled when the text field is non-empty AND `isSending` is false
- Disabled (muted appearance) when the text field is empty OR a message is currently being sent
- Clicking the button sends the message and clears the input field

### 8.4 Keyboard shortcuts

| Key combination | Action |
|-----------------|--------|
| **Enter** | Send the message (if non-empty and not currently sending) |
| **Shift+Enter** | Insert a new line in the input field |

### 8.5 Disabled state

While `isSending` is true:

- The text field is read-only (user cannot type)
- The Send button is disabled
- This prevents sending multiple messages before the LLM responds

---

## 9. Chat Sessions

### 9.1 Creating a new session

- The **New Chat** toolbar button creates a new empty session
- The new session becomes the active session
- The message list clears and the body state transitions to Empty
- The previous session is preserved in the sessions list

### 9.2 Switching sessions

- The **History** popover lists all available sessions
- Clicking a session in the list loads it as the active session
- The message list repopulates with the selected session's messages
- The body state transitions to Active (if the session has messages) or Empty (if the session has no messages)

### 9.3 Session titles

- A new session starts with the title "New Chat"
- After the first user message is sent, the session title updates to a truncated version of that first message
- Session titles are display-only (not user-editable in rev 1)

### 9.4 Session persistence

Sessions are persisted so they survive page reloads and revisits. The persistence mechanism is an implementation detail (local storage, server-side, or hybrid) and is out of scope for this spec.

---

## 10. Focus Context (Inbound EventBus)

The Chat Box receives focus context from other windows via the EventBus. This context is automatically included with every message sent to the LLM, so the assistant has awareness of what the user is looking at.

### 10.1 Focus context payload

The focus context contains:

- Source window (e.g. "File Navigator", "Workflow Viewer")
- Node/item identifier
- Node/item type (e.g. "DataStep", "Workflow", "File")
- Node/item name
- Additional context (e.g. workflow ID, project path)

### 10.2 Focus context display

The current focus context is displayed as a small, unobtrusive indicator near the input area or at the top of the message list:

- Shows the focused item name and source window
- Uses muted styling (small text, secondary colour)
- Updates live as the user clicks in other windows
- When no focus context is set, the indicator is hidden

### 10.3 Focus context in messages

When the user sends a message, the current focus context is attached to the request payload sent to the LLM API. This gives the assistant full awareness of the user's current navigation state without the user needing to describe it.

---

## 11. Action Intents (Outbound EventBus)

The LLM's responses may contain action intents -- instructions for the platform to perform operations. These are emitted on the EventBus for the Frame orchestrator to execute.

### 11.1 Action intent types

| Intent | Payload | Effect |
|--------|---------|--------|
| `createStep` | step type, workflow ID, configuration | Frame creates a step in the workflow |
| `openFile` | file ID, project ID | Frame opens the file in the appropriate viewer |
| `openWorkflow` | workflow ID | Frame opens the Workflow Viewer for the specified workflow |
| `navigateToStep` | step ID, workflow ID | Workflow Viewer scrolls to and focuses the specified step |
| `navigateTo` | node ID or path | File Navigator expands to and highlights the specified node |
| `refreshTree` | -- | File Navigator re-fetches data |
| `workflowUpdated` | workflow ID | Workflow Viewer re-fetches and re-renders |

### 11.2 Intent execution model

The Chat Box does not execute intents directly. It emits them on the EventBus and the Frame orchestrator routes them. The chat does not need to know whether an intent succeeded or failed -- subsequent focus events and user messages provide that feedback loop.

---

## 12. EventBus Communication

### 12.1 Events the chat emits

| Event | Payload | Triggered by |
|-------|---------|-------------|
| `createStep` | step type, workflow ID, configuration | LLM response containing a create-step action |
| `openFile` | file ID, project ID | LLM response containing an open-file action |
| `openWorkflow` | workflow ID | LLM response containing an open-workflow action |
| `navigateToStep` | step ID, workflow ID | LLM response directing attention to a step |
| `navigateTo` | node ID or path | LLM response directing attention to a file/project |
| `refreshTree` | -- | LLM response after file operations |
| `workflowUpdated` | workflow ID | LLM response after workflow modifications |

### 12.2 Events the chat listens to

| Event | Payload | Action |
|-------|---------|--------|
| `focusChanged` | source, node ID, node type, node name, additional context | Update the focus context state and display indicator |

### 12.3 Window interaction map

| Window | Direction | Event |
|--------|-----------|-------|
| File Navigator (1) | Navigator --> Chat | `focusChanged` -- user clicked a file, project, or folder |
| Workflow Viewer (3) | Viewer --> Chat | `focusChanged` -- user clicked a step or workflow root |
| Chat (2) | Chat --> Workflow Viewer | `navigateToStep` -- LLM directs attention to a step |
| Chat (2) | Chat --> Workflow Viewer | `workflowUpdated` -- LLM modified workflow structure |
| Chat (2) | Chat --> Workflow Viewer | `openWorkflow` -- LLM opens a workflow |
| Chat (2) | Chat --> File Navigator | `navigateTo` -- LLM directs attention to a file |
| Chat (2) | Chat --> File Navigator | `refreshTree` -- LLM performed file operations |
| Chat (2) | Chat --> Frame | `createStep` -- LLM creates a workflow step |
| Chat (2) | Chat --> Frame | `openFile` -- LLM opens a file in a viewer |

### 12.4 EventBus scope note

EventBus message definitions and payloads are **out of scope** for the Phase 2 mock build. The controls and visual states described above will be implemented with mock data and local state changes. Actual EventBus wiring will be provided by the EventBus developer in Phase 3.

---

## 13. Service Interfaces

The chat depends on two services, which will have mock (Phase 2) and real (Phase 3) implementations.

### 13.1 Chat service

Responsible for communication with the LLM API:

- **Send message** -- given a session ID, message text, and focus context, sends the message to the LLM API and returns the assistant's response
- **Load session** -- given a session ID, returns the full session with all messages
- **List sessions** -- returns all sessions for the current user, ordered by most recent activity
- **Create session** -- creates a new empty session and returns it

### 13.2 Event bus service

Responsible for communication with the Frame and other windows:

**Emits:**

- Create step (step type, workflow ID, configuration)
- Open file (file ID, project ID)
- Open workflow (workflow ID)
- Navigate to step (step ID, workflow ID)
- Navigate to (node ID or path)
- Refresh tree (no payload)
- Workflow updated (workflow ID)

**Listens to:**

- Focus changed (source, node ID, node type, node name, additional context)

---

## 14. Mock Data

Phase 2 requires canned conversations that exercise the full rendering surface.

### 14.1 Session 1: "Workflow setup"

A conversation about building a flow cytometry analysis pipeline. Messages should include:

- User asks the LLM to create a workflow
- Assistant responds with an explanation and a YAML code block showing the workflow structure
- User asks to add a PhenoGraph clustering step
- Assistant responds with markdown containing a numbered list of steps, a fenced Dart code block, and a table comparing clustering parameters

### 14.2 Session 2: "Data import help"

A conversation about importing and inspecting data. Messages should include:

- User asks how to upload FCS files
- Assistant responds with step-by-step instructions using bold text, bullet lists, and an inline code reference to a file path
- User asks about column mapping
- Assistant responds with a markdown table showing source columns mapped to Tercen schema columns, plus a fenced JSON code block

### 14.3 Session 3: "Error troubleshooting"

A conversation about debugging a failed step. Messages should include:

- User reports that a step failed
- Assistant responds with a block quote containing the error message, followed by a diagnosis using headings (h3, h4), bullet lists, and a fenced Python code block with a fix
- User confirms the fix worked
- Assistant responds with a brief acknowledgement

### 14.4 Mock focus context

The mock data service should provide a static focus context that updates when the user interacts with the mock. For Phase 2, a default focus context of "Flow Immunophenotyping" workflow from the File Navigator is sufficient.

### 14.5 Mock LLM responses

The mock chat service returns pre-defined assistant responses (not actual LLM calls). Each mock response is returned after a brief simulated delay to exercise the sending indicator state.

---

## 15. Implementation Guidance

The message list should leverage a mature open-source chat UI library for scroll management, auto-scroll suppression, and message layout rather than building these mechanics from scratch. Assistant message rendering should use a markdown rendering library with support for fenced code blocks and syntax highlighting. All visual styling must conform to the shared design token system — no default library styling should be visible in the final appearance.

---

## 16. What the Chat Box Does NOT Do

| Action | Where it is handled |
|--------|-------------------|
| Execute Tercen MCP tool calls directly | LLM backend (server-side) |
| Render step configuration forms | Step viewer windows (Window 4, 5, 6) |
| Display workflow visualisations | Workflow Viewer (Window 3) |
| Browse files or projects | File Navigator (Window 1) |
| Display computation logs | Audit Trail (Window 7) |
| Provide a model picker or LLM configuration | Out of scope for rev 1 |
| Stream partial responses in real-time | Out of scope for rev 1 (responses arrive complete) |
| Copy or retry individual messages | Out of scope for rev 1 |
| Edit or delete sent messages | Out of scope for rev 1 |
| Rename or delete chat sessions | Out of scope for rev 1 |
| File or image attachments in messages | Out of scope for rev 1 |

---

## 17. Wireframe

```text
+--------------------------------------------------------------+
| [+ New Chat]  ........................  [History]             |  <- Toolbar
+--------------------------------------------------------------+
|                                                              |
|  Focus: Flow Immunophenotyping (Workflow Viewer)             |  <- Focus indicator
|                                                              |
|         +------------------------------------------+         |
|         | How do I add a clustering step to my     |  12:03  |  <- User message
|         | workflow?                                 |         |
|         +------------------------------------------+         |
|                                                              |
|  +---------------------------------------------------+       |
|  | To add a clustering step, follow these steps:      |       |  <- Assistant message
|  |                                                    |       |     (rich markdown)
|  | 1. **Select the target step** in the Workflow      |       |
|  |    Viewer                                          |       |
|  | 2. The step will be added after the selected       |       |
|  |    step                                            |       |
|  |                                                    |       |
|  | Here is the configuration:                         |       |
|  |                                                    |       |
|  | ```yaml                                            |       |  <- Fenced code block
|  | step:                                              |       |     with syntax highlighting
|  |   type: DataStep                                   |       |
|  |   operator: PhenoGraph                             |       |
|  |   parameters:                                      |       |
|  |     k: 30                                          |       |
|  | ```                                                |       |
|  |                                                    |       |
|  | | Parameter | Default | Range    |                 |       |  <- Markdown table
|  | |-----------|---------|----------|                 |       |
|  | | k         | 30      | 10-100   |                 |       |
|  | | metric    | cosine  | --       |                 |       |
|  |                                          12:03     |       |
|  +---------------------------------------------------+       |
|                                                              |
+--------------------------------------------------------------+
| [Type a message...                           ] [Send]        |  <- Input area
+--------------------------------------------------------------+
```

---

## 18. LLM Integration

The LLM interacts with the Chat Box as follows:

1. **Receives messages** -- user messages are sent to the LLM API along with the current focus context. The LLM receives full awareness of what window the user is looking at and what item is selected.

2. **Returns rich responses** -- the LLM's response is a markdown string that the Chat Box renders with full formatting, code blocks, and tables.

3. **Emits action intents** -- when the LLM determines that a platform operation is needed (create step, open file, navigate), the response includes structured action intents that the Chat Box emits on the EventBus.

4. **Reads focus updates** -- as the user clicks around in other windows, focus context events flow into the Chat Box. The LLM sees this context with every subsequent message, enabling context-aware assistance.

5. **Does not control the UI directly** -- the LLM communicates through the Chat Box and EventBus. It cannot manipulate other windows directly.

---

## 19. Decision Log

Decisions made during the design process, for reference:

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | No streaming responses in rev 1 | Simplifies the message rendering pipeline. Responses arrive complete. Streaming can be added in a future revision. |
| 2 | No message actions (copy, retry) in rev 1 | Keeps the message UI clean and simple. These can be added later without architectural changes. |
| 3 | No model picker | The platform uses Claude exclusively. No need to expose model selection to users. |
| 4 | Session title derived from first user message | Avoids requiring the user to name sessions. Automatic titling provides enough context for the session switcher. |
| 5 | Focus context displayed as a subtle indicator | Focus context is critical for LLM accuracy but should not dominate the chat UI. A small indicator near the input area is sufficient. |
| 6 | Bidirectional EventBus (not send-only) | The chat must both receive focus context from other windows and emit action intents back. This makes it the central coordination point for LLM-driven operations. |
| 7 | Enter to send, Shift+Enter for new line | Standard convention in chat applications. Minimises friction for quick messages while supporting multi-line input. |
| 8 | Input disabled while sending | Prevents race conditions where multiple user messages are sent before the LLM responds. Ensures a clean request-response flow. |
| 9 | Use open-source chat UI library for message list | Provides scroll management, auto-scroll suppression, and message layout out of the box. Avoids reimplementing common chat patterns. |
| 10 | Use open-source markdown library for assistant rendering | Mature rendering with broad markdown support. Code block rendering and theming can be customised. |
| 11 | Sessions not editable or deletable in rev 1 | Keeps session management simple. Users can create new sessions and switch between them. Editing and deletion can be added later. |
| 12 | Mock LLM responses with simulated delay | Phase 2 exercises the full sending-indicator flow without requiring an actual LLM backend. |
| 13 | The chat conforms to skeleton-window from tercen-flutter-skills | Ensures consistency with all other Tercen windows: same theming, state management, DI, and mock/real switching patterns. |

---

## 20. Open Questions

| # | Question | Impact |
|---|----------|--------|
| 1 | **Focus context placement** -- Should the focus indicator be above the message list, below the toolbar, or inline with the input area? | Affects layout and visual hierarchy. Current spec says "near the input area or at the top of the message list." |
| 2 | **Session storage** -- Should sessions persist server-side (tied to Tercen user account) or client-side (local storage)? | Affects whether sessions survive across devices and browsers. |
| 3 | **Action intent format** -- How are structured action intents encoded in the LLM response? Separate JSON field, tool-use blocks, or parsed from markdown? | Affects the chat service interface and EventBus emission logic. |
| 4 | **Maximum message length** -- Should there be a character limit on user messages? | Affects input validation and LLM API token budgets. |
| 5 | **Session limit** -- Should there be a cap on the number of stored sessions or messages per session? | Affects storage and performance for heavy users. |
| 6 | **Multi-window focus** -- If multiple windows emit `focusChanged` in quick succession, does the chat keep only the latest, or maintain a stack of recent focus contexts? | Affects the focus context payload sent to the LLM. |
| 7 | **Error recovery** -- If the LLM API returns an error for a specific message, should the error be shown inline in the message list or as a global error state? | Inline errors allow the conversation to continue; global errors block the entire window. |
