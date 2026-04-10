import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../error_reporter.dart';
import '../event_bus/event_bus.dart';
import '../event_bus/event_payload.dart';
import '../renderer/sdui_render_context.dart';
import '../schema/prop_converter.dart';
import '../schema/sdui_node.dart';
import '../state/state_manager.dart';
import '../theme/sdui_theme.dart';
import 'behavior_widgets.dart';
import 'widget_metadata.dart';
import 'widget_registry.dart';

/// Register Flutter primitive widgets (Tier 1) and behavior widgets into the registry.
void registerBuiltinWidgets(WidgetRegistry registry) {
  registerBehaviorWidgets(registry);
  // Layout primitives
  registry.register('Row', _buildRow,
      metadata: const WidgetMetadata(
        type: 'Row',
        description: 'Horizontal layout',
        props: {
          'mainAxisAlignment': PropSpec(type: 'string', defaultValue: 'start'),
          'crossAxisAlignment': PropSpec(type: 'string', defaultValue: 'center'),
          'mainAxisSize': PropSpec(type: 'string', defaultValue: 'max',
              description: '"max" fills available space, "min" shrinks to children'),
          'clipBehavior': PropSpec(type: 'string',
              description: 'Clip behavior: "hardEdge", "antiAlias", "none" (default)'),
        },
      ));

  registry.register('Column', _buildColumn,
      metadata: const WidgetMetadata(
        type: 'Column',
        description: 'Vertical layout',
        props: {
          'mainAxisAlignment': PropSpec(type: 'string', defaultValue: 'start'),
          'crossAxisAlignment': PropSpec(type: 'string', defaultValue: 'center'),
          'mainAxisSize': PropSpec(type: 'string', description: "Controls whether Column shrink-wraps ('min') or fills available space ('max'). Default: 'max'"),
        },
      ));

  registry.register('Container', _buildContainer,
      metadata: const WidgetMetadata(
        type: 'Container',
        description: 'Box with optional padding, color, border, and constraints',
        props: {
          'color': PropSpec(type: 'string'),
          'padding': PropSpec(type: 'number'),
          'width': PropSpec(type: 'number'),
          'height': PropSpec(type: 'number'),
          'borderColor': PropSpec(type: 'string', description: 'Border color (semantic token or hex)'),
          'borderWidth': PropSpec(type: 'number', description: 'Border width in px (default 1)'),
          'borderRadius': PropSpec(type: 'number', description: 'Corner radius in px'),
          'elevation': PropSpec(type: 'number', description: 'Drop shadow elevation'),
          'maxWidth': PropSpec(type: 'number', description: 'Maximum width constraint in pixels'),
          'maxHeight': PropSpec(type: 'number', description: 'Maximum height constraint in pixels'),
          'clipBehavior': PropSpec(type: 'string',
              description: 'Clip behavior: "hardEdge", "antiAlias", "none" (default)'),
        },
      ));

  registry.register('Text', _buildText,
      metadata: const WidgetMetadata(
        type: 'Text',
        description: 'Text display. When maxLines is set, truncates with ellipsis and shows '
            'a tooltip with the full text on hover.',
        props: {
          'text': PropSpec(type: 'string', required: true),
          'textStyle': PropSpec(type: 'string',
              description: 'M3 TextTheme slot name (bodyMedium, headlineLarge, etc.)'),
          'fontSize': PropSpec(type: 'number', defaultValue: 14),
          'color': PropSpec(type: 'string'),
          'fontWeight': PropSpec(type: 'string'),
          'maxLines': PropSpec(type: 'int',
              description: 'Maximum number of lines. Truncates with ellipsis and shows tooltip on hover.'),
        },
      ));

  registry.register('SelectableText', _buildSelectableText,
      metadata: const WidgetMetadata(
        type: 'SelectableText',
        description: 'Selectable text display. User can select and copy text. '
            'Supports the same styling props as Text.',
        props: {
          'text': PropSpec(type: 'string', required: true),
          'textStyle': PropSpec(type: 'string',
              description: 'M3 TextTheme slot name (bodyMedium, headlineLarge, etc.)'),
          'fontSize': PropSpec(type: 'number', defaultValue: 14),
          'color': PropSpec(type: 'string'),
          'fontWeight': PropSpec(type: 'string'),
          'maxLines': PropSpec(type: 'int',
              description: 'Maximum lines to display. Omit for unlimited.'),
          'textAlign': PropSpec(type: 'string', defaultValue: 'start',
              values: ['start', 'end', 'center', 'justify']),
        },
      ));

  registry.register('Markdown', _buildMarkdown,
      metadata: const WidgetMetadata(
        type: 'Markdown',
        description: 'Renders markdown content with syntax-highlighted code blocks, '
            'tables, headings, lists, bold/italic, links, and blockquotes. '
            'Theme-aware — all styling derived from semantic tokens.',
        props: {
          'content': PropSpec(type: 'string', required: true,
              description: 'Markdown string to render'),
          'selectable': PropSpec(type: 'bool', defaultValue: false,
              description: 'Whether text can be selected and copied'),
        },
      ));

  registry.register('Expanded', _buildExpanded,
      metadata: const WidgetMetadata(
        type: 'Expanded',
        description: 'Expand child to fill available space',
        props: {'flex': PropSpec(type: 'int', defaultValue: 1)},
      ));

  registry.register('Flexible', _buildFlexible,
      metadata: const WidgetMetadata(
        type: 'Flexible',
        description: 'Allow child to shrink within a Row/Column. Unlike Expanded, '
            'Flexible children can be smaller than their flex share.',
        props: {'flex': PropSpec(type: 'int', defaultValue: 1)},
      ));

  registry.register('SizedBox', _buildSizedBox,
      metadata: const WidgetMetadata(
        type: 'SizedBox',
        description: 'Fixed-size box or spacer',
        props: {
          'width': PropSpec(type: 'number'),
          'height': PropSpec(type: 'number'),
        },
      ));

  registry.register('Center', _buildCenter,
      metadata: const WidgetMetadata(
        type: 'Center',
        description: 'Center child within parent',
      ));

  registry.register('Spacer', _buildSpacer,
      metadata: const WidgetMetadata(
        type: 'Spacer',
        description: 'Flexible space in Row/Column',
        props: {'flex': PropSpec(type: 'int', defaultValue: 1)},
      ));

  registry.register('ListView', _buildListView,
      metadata: const WidgetMetadata(
        type: 'ListView',
        description: 'Scrollable list of children',
        props: {
          'padding': PropSpec(type: 'number'),
        },
      ));

  registry.register('Grid', _buildGrid,
      metadata: const WidgetMetadata(
        type: 'Grid',
        description: 'Responsive grid layout with variable-height children',
        props: {
          'columns': PropSpec(type: 'int', required: true, defaultValue: 2),
          'minColumnWidth': PropSpec(type: 'number', defaultValue: 300),
          'spacing': PropSpec(type: 'number', defaultValue: 16),
          'runSpacing': PropSpec(type: 'number', defaultValue: 16),
        },
      ));

  registry.register('Wrap', _buildWrap,
      metadata: const WidgetMetadata(
        type: 'Wrap',
        description: 'Flow layout that wraps children to next line',
        props: {
          'spacing': PropSpec(type: 'number', defaultValue: 8),
          'runSpacing': PropSpec(type: 'number', defaultValue: 8),
          'alignment': PropSpec(type: 'string', defaultValue: 'start',
              values: ['start', 'end', 'center', 'spaceBetween', 'spaceAround', 'spaceEvenly']),
        },
      ));

  registry.register('FormDialog', _buildFormDialog,
      metadata: const WidgetMetadata(
        type: 'FormDialog',
        description: 'Modal dialog overlay. Renders children as dialog content using '
            'standard SDUI primitives. Visibility controlled via "visible" prop or '
            'EventBus channel. Use Column, Row, TextField, Switch, PrimaryButton, '
            'GhostButton etc. as children for form layout.',
        props: {
          'title': PropSpec(type: 'string',
              description: 'Dialog header text'),
          'visible': PropSpec(type: 'bool', defaultValue: true,
              description: 'Show or hide the dialog'),
          'modal': PropSpec(type: 'bool', defaultValue: true,
              description: 'If true, scrim blocks click-through'),
          'width': PropSpec(type: 'number', defaultValue: 420,
              description: 'Dialog width in pixels'),
        },
      ));

  registry.register('Card', _buildCard,
      metadata: const WidgetMetadata(
        type: 'Card',
        description: 'Material card with elevation',
        props: {
          'elevation': PropSpec(type: 'number', defaultValue: 1),
          'color': PropSpec(type: 'string'),
        },
      ));

  registry.register('DashboardCard', _buildDashboardCard,
      metadata: const WidgetMetadata(
        type: 'DashboardCard',
        description: 'Standardised card with colored header bar (icon + title), '
            'body area for children, and optional footer slot. '
            'Uses surface/surfaceContainer color hierarchy for consistent styling.',
        props: {
          'title': PropSpec(type: 'string', required: true,
              description: 'Card header title text'),
          'icon': PropSpec(type: 'string',
              description: 'Icon name for the header (e.g. "folder_open")'),
          'footerSlot': PropSpec(type: 'int', defaultValue: -1,
              description: 'Index of the child to render as footer (-1 = no footer). '
                  'The footer child is removed from the body and placed below a divider.'),
          'searchable': PropSpec(type: 'bool', defaultValue: false,
              description: 'Show a search icon in the header. Toggling it reveals '
                  'a text field that publishes filter events on card.<id>.filter channel.'),
          'pageSizes': PropSpec(type: 'list',
              description: 'List of page size options (e.g. [5, 10, 20]). '
                  'Renders a footer with size buttons. Requires pageSizeChannel.'),
          'pageSizeChannel': PropSpec(type: 'string',
              description: 'EventBus channel to publish page size changes '
                  '(e.g. "state.hp-proj-ps.set"). Also listens for current value.'),
          'defaultPageSize': PropSpec(type: 'int',
              description: 'Initial active page size. Defaults to first item in pageSizes.'),
        },
      ));

  registry.register('Padding', _buildPadding,
      metadata: const WidgetMetadata(
        type: 'Padding',
        description: 'Add padding around child',
        props: {
          'padding': PropSpec(type: 'number', required: true, defaultValue: 8),
          'color': PropSpec(type: 'string', description: 'Background color token name. Wraps content in a ColoredBox when set'),
        },
      ));

  registry.register('LoadingIndicator', _buildLoadingIndicator,
      metadata: const WidgetMetadata(
        type: 'LoadingIndicator',
        description: 'Loading indicator with spinner, linear, or skeleton variants',
        props: {
          'variant': PropSpec(type: 'string', defaultValue: 'spinner',
              values: ['spinner', 'linear', 'skeleton']),
          'width': PropSpec(type: 'number'),
          'height': PropSpec(type: 'number'),
          'color': PropSpec(type: 'string'),
          'text': PropSpec(type: 'string'),
        },
      ));

  registry.register('Icon', _buildIcon,
      metadata: const WidgetMetadata(
        type: 'Icon',
        description: 'Font Awesome 6 icon. Default weight is "solid" (filled). '
            'Use weight: "regular" for line-style icons (available for ~169 icons). '
            'Solid is always safe — all 1400+ FA6 Free icons have solid glyphs.',
        props: {
          'icon': PropSpec(type: 'string', required: true,
              description: 'Icon name (e.g., folder, search, add, delete, settings)'),
          'size': PropSpec(type: 'number',
              description: 'Icon size in pixels. Defaults to theme iconSize.md'),
          'color': PropSpec(type: 'string'),
          'weight': PropSpec(type: 'string', defaultValue: 'solid',
              description: 'Font weight: "solid" (filled, default) or "regular" (line style — ~169 icons)',
              values: ['solid', 'regular']),
        },
      ));

  // -- Interactive widgets --

  registry.register('TextField', _buildTextField,
      metadata: const WidgetMetadata(
        type: 'TextField',
        description: 'Text input field. Publishes value to EventBus channel "input.<id>.changed" on each change and "input.<id>.submitted" on submit.',
        props: {
          'hint': PropSpec(type: 'string', description: 'Placeholder text'),
          'value': PropSpec(type: 'string', description: 'Initial value'),
          'maxLines': PropSpec(type: 'int', defaultValue: 1),
          'obscureText': PropSpec(type: 'bool', defaultValue: false),
          'enabled': PropSpec(type: 'bool', defaultValue: true),
          'autofocus': PropSpec(type: 'bool', defaultValue: false),
          'color': PropSpec(type: 'string'),
          'clearOn': PropSpec(type: 'string',
              description: 'EventBus channel — clears the text field when an event arrives'),
          'borderless': PropSpec(type: 'bool', description: 'When true, removes all input borders and fill for inline/embedded use'),
          'label': PropSpec(type: 'string', description: 'Label text displayed above the text field'),
          'submitOnEnter': PropSpec(type: 'bool', description: 'When true on multiline fields, Enter submits and Shift+Enter adds newline'),
          'fontFamily': PropSpec(type: 'string', description: 'Font family for input text (e.g., "monospace")'),
          'prefixIcon': PropSpec(type: 'string', description: 'Icon name shown at the start of the field (e.g., "search")'),
          'size': PropSpec(type: 'string', description: 'Control height tier: "sm" (28px — compact/toolbar), "md" (36px — default). Only applies to single-line bordered fields.'),
        },
      ));

  // Button hierarchy: Primary → Secondary → Ghost → Destructive
  // Style guide names are the canonical API. Flutter class names kept as aliases.

  registry.register('PrimaryButton', _buildElevatedButton,
      metadata: const WidgetMetadata(
        type: 'PrimaryButton',
        description: 'Primary filled button (style guide). Publishes to EventBus channel on tap.',
        props: {
          'text': PropSpec(type: 'string', required: true),
          'channel': PropSpec(type: 'string', required: true,
              description: 'EventBus channel to publish on tap'),
          'payload': PropSpec(type: 'object', description: 'Data to publish'),
          'color': PropSpec(type: 'string'),
          'enabled': PropSpec(type: 'bool', defaultValue: true),
        },
      ));
  // Alias: Flutter name
  registry.register('ElevatedButton', _buildElevatedButton,
      metadata: const WidgetMetadata(
        type: 'ElevatedButton',
        description: 'Alias for PrimaryButton. Filled button that publishes to EventBus channel on tap.',
        props: {
          'text': PropSpec(type: 'string', required: true),
          'channel': PropSpec(type: 'string', required: true),
          'payload': PropSpec(type: 'object'),
          'color': PropSpec(type: 'string'),
          'enabled': PropSpec(type: 'bool', defaultValue: true),
        },
      ));

  registry.register('SecondaryButton', _buildOutlinedButton,
      metadata: const WidgetMetadata(
        type: 'SecondaryButton',
        description: 'Secondary outlined button (style guide). Transparent bg, primary border. Publishes to EventBus channel on tap.',
        props: {
          'text': PropSpec(type: 'string', required: true),
          'channel': PropSpec(type: 'string', required: true),
          'payload': PropSpec(type: 'object'),
          'color': PropSpec(type: 'string'),
          'enabled': PropSpec(type: 'bool', defaultValue: true),
        },
      ));

  registry.register('GhostButton', _buildTextButton,
      metadata: const WidgetMetadata(
        type: 'GhostButton',
        description: 'Ghost text-only button (style guide). No background or border. Publishes to EventBus channel on tap.',
        props: {
          'text': PropSpec(type: 'string', required: true),
          'channel': PropSpec(type: 'string', required: true),
          'payload': PropSpec(type: 'object'),
          'color': PropSpec(type: 'string'),
          'enabled': PropSpec(type: 'bool', defaultValue: true),
        },
      ));
  // Alias: Flutter name
  registry.register('TextButton', _buildTextButton,
      metadata: const WidgetMetadata(
        type: 'TextButton',
        description: 'Alias for GhostButton. Text-only button that publishes to EventBus channel on tap.',
        props: {
          'text': PropSpec(type: 'string', required: true),
          'channel': PropSpec(type: 'string', required: true),
          'payload': PropSpec(type: 'object'),
          'color': PropSpec(type: 'string'),
          'enabled': PropSpec(type: 'bool', defaultValue: true),
        },
      ));

  registry.register('IconButton', _buildIconButton,
      metadata: const WidgetMetadata(
        type: 'IconButton',
        description: 'Icon button with optional variant styling. Publishes to EventBus channel on tap. '
            'Use variant "toolbar-primary" for filled toolbar buttons or "toolbar-secondary" for outlined toolbar buttons. '
            'Default (no variant) renders a bare icon button.',
        props: {
          'icon': PropSpec(type: 'string', required: true,
              description: 'Icon name (e.g., send, add, delete)'),
          'channel': PropSpec(type: 'string', required: true),
          'payload': PropSpec(type: 'object'),
          'size': PropSpec(type: 'number',
              description: 'Icon size override. Defaults to theme iconSize.md (bare) or window.toolbarButtonIconSize (toolbar variants)'),
          'color': PropSpec(type: 'string'),
          'tooltip': PropSpec(type: 'string'),
          'enabled': PropSpec(type: 'bool', defaultValue: true),
          'variant': PropSpec(type: 'string',
              description: 'Styling variant: "toolbar-primary" (filled), "toolbar-secondary" (outlined), or omit for bare icon button'),
          'weight': PropSpec(type: 'string', defaultValue: 'solid',
              description: 'Font weight: "solid" (filled, default) or "regular" (line style — ~169 icons)',
              values: ['solid', 'regular']),
          'stateChannel': PropSpec(type: 'string',
              description: 'EventBus channel for reactive updates. When set on toolbar variants, '
                  'the button subscribes and dynamically updates its icon/tooltip from event payload '
                  '({icon, tooltip}). Used for toggle-style toolbar buttons.'),
        },
      ));

  registry.register('ToggleButton', _buildToggleButton,
      metadata: const WidgetMetadata(
        type: 'ToggleButton',
        description: 'Toggle button. Off=Secondary (outlined), On=Primary (filled). '
            'Publishes to "input.<id>.changed" with {value: bool} on each tap. '
            'Accepts icon, text, or both.',
        props: {
          'icon': PropSpec(type: 'string',
              description: 'Icon name (optional)'),
          'text': PropSpec(type: 'string',
              description: 'Button text (optional)'),
          'value': PropSpec(type: 'bool', defaultValue: false),
          'tooltip': PropSpec(type: 'string'),
          'enabled': PropSpec(type: 'bool', defaultValue: true),
        },
      ));

  registry.register('DangerButton', _buildDangerButton,
      metadata: const WidgetMetadata(
        type: 'DangerButton',
        description: 'Destructive action button (style guide). Red outlined, red filled on hover. Publishes to EventBus channel on tap.',
        props: {
          'text': PropSpec(type: 'string', required: true),
          'channel': PropSpec(type: 'string', required: true,
              description: 'EventBus channel to publish on tap'),
          'payload': PropSpec(type: 'object', description: 'Data to publish'),
          'enabled': PropSpec(type: 'bool', defaultValue: true),
        },
      ));

  registry.register('SubtleButton', _buildSubtleButton,
      metadata: const WidgetMetadata(
        type: 'SubtleButton',
        description: 'Low-emphasis button (style guide). Tinted background, no border. Publishes to EventBus channel on tap.',
        props: {
          'text': PropSpec(type: 'string', required: true),
          'channel': PropSpec(type: 'string', required: true,
              description: 'EventBus channel to publish on tap'),
          'payload': PropSpec(type: 'object', description: 'Data to publish'),
          'enabled': PropSpec(type: 'bool', defaultValue: true),
        },
      ));

  registry.register('Radio', _buildRadio,
      metadata: const WidgetMetadata(
        type: 'Radio',
        description: 'Radio button for single-select within a group. '
            'Publishes to "input.<id>.changed" with {value: String} when selected.',
        props: {
          'value': PropSpec(type: 'string', required: true,
              description: 'The value this radio represents'),
          'groupValue': PropSpec(type: 'string',
              description: 'Currently selected value in the group'),
          'label': PropSpec(type: 'string',
              description: 'Label text displayed next to the radio'),
          'enabled': PropSpec(type: 'bool', defaultValue: true),
          'color': PropSpec(type: 'string'),
          'channel': PropSpec(type: 'string',
              description: 'Optional EventBus channel override. Default: "input.<id>.changed"'),
        },
      ));

  registry.register('RadioGroup', _buildRadioGroup,
      metadata: const WidgetMetadata(
        type: 'RadioGroup',
        description: 'Group of radio buttons for single-select. '
            'Publishes to "input.<id>.changed" with {value: String} when selection changes.',
        props: {
          'value': PropSpec(type: 'string',
              description: 'Currently selected value'),
          'items': PropSpec(type: 'list', required: true,
              description: 'List of {value, label} objects'),
          'direction': PropSpec(type: 'string', defaultValue: 'vertical',
              description: 'Layout direction: "vertical" or "horizontal"'),
          'enabled': PropSpec(type: 'bool', defaultValue: true),
          'color': PropSpec(type: 'string'),
        },
      ));

  registry.register('Badge', _buildBadge,
      metadata: const WidgetMetadata(
        type: 'Badge',
        description: 'Status indicator label (style guide). Variants: success, info, warning, error, primary, neutral.',
        props: {
          'text': PropSpec(type: 'string', required: true),
          'variant': PropSpec(type: 'string', defaultValue: 'neutral',
              description: 'One of: success, info, warning, error, primary, neutral'),
        },
      ));

  registry.register('Alert', _buildAlert,
      metadata: const WidgetMetadata(
        type: 'Alert',
        description: 'Inline notification with status accent (style guide). Variants: success, info, warning, error.',
        props: {
          'title': PropSpec(type: 'string'),
          'message': PropSpec(type: 'string', required: true),
          'variant': PropSpec(type: 'string', defaultValue: 'info',
              description: 'One of: success, info, warning, error'),
          'dismissible': PropSpec(type: 'bool', defaultValue: false,
              description: 'Show a close button'),
          'channel': PropSpec(type: 'string',
              description: 'EventBus channel to publish on dismiss'),
        },
      ));

  registry.register('Slider', _buildSlider,
      metadata: const WidgetMetadata(
        type: 'Slider',
        description: 'Range value input (style guide). '
            'Publishes to "input.<id>.changed" with {value: double} on change.',
        props: {
          'value': PropSpec(type: 'number', defaultValue: 0),
          'min': PropSpec(type: 'number', defaultValue: 0),
          'max': PropSpec(type: 'number', defaultValue: 1),
          'divisions': PropSpec(type: 'number',
              description: 'Number of discrete divisions. If null, slider is continuous.'),
          'label': PropSpec(type: 'string',
              description: 'Label displayed above the slider'),
          'enabled': PropSpec(type: 'bool', defaultValue: true),
          'color': PropSpec(type: 'string'),
        },
      ));

  registry.register('TabBar', _buildTabBar,
      metadata: const WidgetMetadata(
        type: 'TabBar',
        description: 'Generic tab bar for content-level tab navigation. '
            'Publishes to "input.<id>.changed" with {value: int, tab: String} when tab changes.',
        props: {
          'tabs': PropSpec(type: 'list', required: true,
              description: 'List of {label, icon?} objects'),
          'selected': PropSpec(type: 'number', defaultValue: 0,
              description: 'Index of the initially selected tab'),
          'color': PropSpec(type: 'string'),
        },
      ));

  registry.register('PopupMenu', _buildPopupMenu,
      metadata: const WidgetMetadata(
        type: 'PopupMenu',
        description: 'Icon button that opens a popup menu. Each item publishes to the '
            'specified channel with the item value in the payload. '
            'Set multiSelect:true for checkbox mode (stays open, publishes selected set).',
        props: {
          'icon': PropSpec(type: 'string', defaultValue: 'more_vert',
              description: 'Trigger icon name'),
          'iconSize': PropSpec(type: 'number', defaultValue: 24),
          'iconColor': PropSpec(type: 'string'),
          'tooltip': PropSpec(type: 'string'),
          'variant': PropSpec(type: 'string',
              description: 'Styling variant: "toolbar-primary", "toolbar-secondary", or omit for default'),
          'channel': PropSpec(type: 'string', required: true,
              description: 'EventBus channel to publish selected item(s)'),
          'items': PropSpec(type: 'list', required: true,
              description: 'List of {value, label, icon?, divider?, selected?} objects. '
                  'Set divider:true for a separator.'),
          'multiSelect': PropSpec(type: 'bool', defaultValue: false,
              description: 'When true, items render with checkboxes and menu stays open on toggle'),
          'iconOnly': PropSpec(type: 'bool', defaultValue: false),
        },
      ));

  registry.register('Switch', _buildSwitch,
      metadata: const WidgetMetadata(
        type: 'Switch',
        description: 'Toggle switch. Publishes to "input.<id>.changed" with {value: bool}.',
        props: {
          'value': PropSpec(type: 'bool', defaultValue: false),
          'enabled': PropSpec(type: 'bool', defaultValue: true),
          'color': PropSpec(type: 'string'),
        },
      ));

  registry.register('Checkbox', _buildCheckbox,
      metadata: const WidgetMetadata(
        type: 'Checkbox',
        description: 'Checkbox. Publishes to "input.<id>.changed" with {value: bool}.',
        props: {
          'value': PropSpec(type: 'bool', defaultValue: false),
          'label': PropSpec(type: 'string'),
          'enabled': PropSpec(type: 'bool', defaultValue: true),
          'color': PropSpec(type: 'string'),
        },
      ));

  registry.register('Divider', _buildDivider,
      metadata: const WidgetMetadata(
        type: 'Divider',
        description: 'Horizontal divider line',
        props: {
          'height': PropSpec(type: 'number', defaultValue: 1),
          'thickness': PropSpec(type: 'number'),
          'color': PropSpec(type: 'string'),
          'indent': PropSpec(type: 'number'),
          'endIndent': PropSpec(type: 'number', description: 'End indent in pixels (mirrors indent value)'),
        },
      ));

  registry.register('Chip', _buildChip,
      metadata: const WidgetMetadata(
        type: 'Chip',
        description: 'Material chip label',
        props: {
          'label': PropSpec(type: 'string', required: true),
          'color': PropSpec(type: 'string'),
          'avatar': PropSpec(type: 'string', description: 'Icon name for avatar'),
        },
      ));

  registry.register('CircleAvatar', _buildCircleAvatar,
      metadata: const WidgetMetadata(
        type: 'CircleAvatar',
        description: 'Circular avatar with text or icon',
        props: {
          'text': PropSpec(type: 'string', description: 'Text to display (first char used)'),
          'icon': PropSpec(type: 'string', description: 'Icon name'),
          'radius': PropSpec(type: 'number', defaultValue: 20),
          'color': PropSpec(type: 'string'),
        },
      ));

  registry.register('DropdownButton', _buildDropdownButton,
      metadata: const WidgetMetadata(
        type: 'DropdownButton',
        description: 'Dropdown selector. Publishes to "input.<id>.changed" with {value: string}.',
        props: {
          'value': PropSpec(type: 'string'),
          'items': PropSpec(type: 'list', required: true,
              description: 'List of strings or {value, label} objects'),
          'hint': PropSpec(type: 'string'),
          'enabled': PropSpec(type: 'bool', defaultValue: true),
          'label': PropSpec(type: 'string', description: 'Label text displayed above the dropdown'),
        },
      ));

  registry.register('Image', _buildImage,
      metadata: const WidgetMetadata(
        type: 'Image',
        description: 'Display an image from a URL',
        props: {
          'src': PropSpec(type: 'string', required: true,
              description: 'Image URL'),
          'width': PropSpec(type: 'number'),
          'height': PropSpec(type: 'number'),
          'fit': PropSpec(type: 'string', defaultValue: 'contain',
              values: ['contain', 'cover', 'fill', 'fitWidth', 'fitHeight', 'none', 'scaleDown']),
          'errorText': PropSpec(type: 'string', defaultValue: 'Image failed to load'),
        },
      ));

  registry.register('Tooltip', _buildTooltip,
      metadata: const WidgetMetadata(
        type: 'Tooltip',
        description: 'Tooltip that appears on hover/long-press around its child',
        props: {
          'message': PropSpec(type: 'string', required: true),
        },
      ));

  registry.register('ProgressBar', _buildProgressBar,
      metadata: const WidgetMetadata(
        type: 'ProgressBar',
        description: 'Linear or circular progress indicator with optional label',
        props: {
          'value': PropSpec(type: 'number',
              description: 'Progress 0.0–1.0. Omit for indeterminate.'),
          'variant': PropSpec(type: 'string', defaultValue: 'linear',
              values: ['linear', 'circular']),
          'color': PropSpec(type: 'string'),
          'backgroundColor': PropSpec(type: 'string'),
          'text': PropSpec(type: 'string'),
        },
      ));

  // -- Data display widgets --

  registry.register('ImageViewer', _buildImageViewer,
      metadata: const WidgetMetadata(
        type: 'ImageViewer',
        description: 'Zoomable image viewer with pan support. Loads an image from a URL '
            'and displays it in an InteractiveViewer with zoom (0.1x–5x) and pan.',
        props: {
          'url': PropSpec(type: 'string', required: true,
              description: 'Image URL to display. Auth tokens should be baked into the URL query params.'),
        },
      ));

  registry.register('TabbedImageViewer', _buildTabbedImageViewer,
      metadata: const WidgetMetadata(
        type: 'TabbedImageViewer',
        description: 'Multi-image viewer with browser-style tabs. Each tab shows a '
            'zoomable image. Accepts an array of images from getStepImages.',
        props: {
          'images': PropSpec(type: 'list', required: true,
              description: 'List of {filename, mimetype, url, schemaId}'),
          'authToken': PropSpec(type: 'string',
              description: 'Authorization token for authenticated URLs'),
        },
      ));

  registry.register('DirectedGraph', _buildDirectedGraph,
      metadata: const WidgetMetadata(
        type: 'DirectedGraph',
        description: 'Interactive directed graph renderer with zoom/pan, node selection, '
            'and path highlighting. Nodes have configurable shapes, icons, and colors. '
            'Publishes selection events on node tap (with nodeId, label, iconColor, shape, subtitle). '
            'Publishes to doubleTapChannel on double-tap. '
            'Highlights nodes whose label matches searchQuery.',
        props: {
          'nodes': PropSpec(type: 'list', required: true,
              description: 'List of {id, label, x, y, width, height, shape, icon, iconColor, fill, borderColor, subtitle?, labelPosition?}'),
          'edges': PropSpec(type: 'list', required: true,
              description: 'List of {from, to}'),
          'channel': PropSpec(type: 'string', defaultValue: 'graph.selection',
              description: 'EventBus channel for single-tap selection events'),
          'doubleTapChannel': PropSpec(type: 'string',
              description: 'EventBus channel for double-tap events (e.g. open step viewer)'),
          'zoomInChannel': PropSpec(type: 'string',
              description: 'EventBus channel to trigger zoom in'),
          'zoomOutChannel': PropSpec(type: 'string',
              description: 'EventBus channel to trigger zoom out'),
          'fitToWindowChannel': PropSpec(type: 'string',
              description: 'EventBus channel to trigger fit-to-window zoom'),
          'stepStateChannel': PropSpec(type: 'string',
              description: 'EventBus channel for incremental step state updates. '
                  'Expects payload with {nodeId, iconColor}. Updates the node\'s icon color '
                  'and spinner state in place without a full re-fetch.'),
          'searchQuery': PropSpec(type: 'string',
              description: 'Static search text (use searchChannel for live search). '
                  'Case-insensitive. Matching node labels get a warningContainer tint.'),
          'searchChannel': PropSpec(type: 'string',
              description: 'EventBus channel for live search input. Expects payload with {value}. '
                  'Updates searchQuery dynamically as the user types.'),
          'emptyIcon': PropSpec(type: 'string',
              description: 'FA6 icon name for the empty state (when nodes list is empty)'),
          'emptyTitle': PropSpec(type: 'string',
              description: 'Title text for the empty state'),
          'emptySubtitle': PropSpec(type: 'string',
              description: 'Subtitle text for the empty state'),
        },
      ));

  // Identicon avatar
  registry.register('Identicon', _buildIdenticon,
      metadata: const WidgetMetadata(
        type: 'Identicon',
        description:
            'Deterministic geometric avatar generated from an identity string. '
            'Produces a GitHub-style 5x5 mirrored pattern unique to each input.',
        props: {
          'identity': PropSpec(
              type: 'string',
              required: true,
              description: 'Identity string (username) to generate pattern from'),
          'size': PropSpec(type: 'number', defaultValue: 24),
          'borderColor': PropSpec(
              type: 'string',
              description: 'Optional border ring color (semantic token)'),
        },
      ));

  // Window shell — skeleton for feature windows (48px toolbar + body)
  registry.register('WindowShell', _buildWindowShell,
      metadata: const WidgetMetadata(
        type: 'WindowShell',
        description:
            'Feature window skeleton: 48px toolbar with action buttons + body content. '
            'Toolbar actions are defined in the toolbarActions prop. Children form the body.',
        props: {
          'toolbarActions': PropSpec(
              type: 'list',
              description:
                  'List of {icon, label?, channel, payload?, isPrimary?} toolbar button descriptors'),
          'showToolbar': PropSpec(
              type: 'bool', defaultValue: true,
              description: 'Whether to show the toolbar'),
        },
      ));

  // Popover — icon button that shows arbitrary SDUI children in a positioned overlay
  registry.register('Popover', _buildPopover,
      metadata: const WidgetMetadata(
        type: 'Popover',
        description: 'Icon button that opens a positioned overlay panel containing arbitrary '
            'SDUI children. Unlike PopupMenu (which only supports menu items), Popover renders '
            'its children as free-form content. Dismisses on outside tap. '
            'Publishes to "<id>.dismissed" when closed.',
        props: {
          'icon': PropSpec(type: 'string', defaultValue: 'circle-info',
              description: 'Trigger icon name (FontAwesome 6)'),
          'tooltip': PropSpec(type: 'string',
              description: 'Tooltip for the trigger button'),
          'variant': PropSpec(type: 'string',
              description: 'Styling variant: "toolbar-primary", "toolbar-secondary", or omit for default'),
          'width': PropSpec(type: 'number', defaultValue: 320,
              description: 'Overlay panel width in pixels'),
          'maxHeight': PropSpec(type: 'number', defaultValue: 400,
              description: 'Maximum overlay panel height in pixels'),
          'title': PropSpec(type: 'string',
              description: 'Optional header title for the popover panel'),
        },
      ));

  // ClipboardCopy — copies text to clipboard, shows brief confirmation
  registry.register('ClipboardCopy', _buildClipboardCopy,
      metadata: const WidgetMetadata(
        type: 'ClipboardCopy',
        description: 'Icon button that copies the specified text to the system clipboard. '
            'Shows a brief check-mark confirmation icon after copying. '
            'Use for copy-ID, copy-URL, copy-value patterns.',
        props: {
          'text': PropSpec(type: 'string', required: true,
              description: 'Text to copy to clipboard'),
          'icon': PropSpec(type: 'string', defaultValue: 'copy',
              description: 'Icon name (FontAwesome 6)'),
          'confirmIcon': PropSpec(type: 'string', defaultValue: 'check',
              description: 'Icon shown briefly after copy succeeds'),
          'tooltip': PropSpec(type: 'string', defaultValue: 'Copy',
              description: 'Tooltip text'),
          'size': PropSpec(type: 'number',
              description: 'Icon size in pixels'),
        },
      ));

  // AnnotatedImageViewer — zoomable image viewer with drawing annotation tools
  registry.register('AnnotatedImageViewer', _buildAnnotatedImageViewer,
      metadata: const WidgetMetadata(
        type: 'AnnotatedImageViewer',
        description: 'Multi-image viewer with browser-style tabs and annotation tools. '
            'Accepts the images array from getStepImages. Provides 6 drawing tools '
            '(polygon, rectangle, circle, arrow, freehand, text), zoom/pan, '
            'send-to-chat (publishes annotation bundle), and save-to-project (browser download). '
            'Built-in toolbar with tool toggles, clear, send, save, and zoom controls.',
        props: {
          'images': PropSpec(type: 'list', required: true,
              description: 'List of {schemaId, filename, mimetype, url} from getStepImages'),
          'authToken': PropSpec(type: 'string',
              description: 'Authorization token for authenticated image URLs'),
          'sendChannel': PropSpec(type: 'string', defaultValue: 'visualization.annotations.send',
              description: 'EventBus channel to publish annotation bundle when Send to Chat is pressed'),
          'annotationColor': PropSpec(type: 'string', defaultValue: '#FF5722',
              description: 'Stroke/fill colour for annotations (hex)'),
        },
      ));

  // WorkflowActionButton — context-sensitive Run/Stop/Reset button
  registry.register('WorkflowActionButton', _buildWorkflowActionButton,
      metadata: const WidgetMetadata(
        type: 'WorkflowActionButton',
        description: 'Context-sensitive primary toolbar button for workflow execution control. '
            'Subscribes to the graph selection channel to detect whether the workflow root '
            'or an individual step is focused. Derives the action (run/stop/reset) from the '
            'focused node\'s iconColor (state). Publishes to distinct channels per action: '
            'runWorkflow, stopWorkflow, resetWorkflow, runStep, stopStep, resetStep. '
            'All channels carry {workflowId} and optionally {stepId} in the payload.',
        props: {
          'selectionChannel': PropSpec(type: 'string', required: true,
              description: 'EventBus channel to subscribe for graph selection events. '
                  'Expects payload with {nodeId, label, iconColor, shape}.'),
          'workflowId': PropSpec(type: 'string', required: true,
              description: 'Workflow ID for action payloads'),
          'runWorkflowChannel': PropSpec(type: 'string', defaultValue: 'workflow.runWorkflow',
              description: 'Channel to publish when Run All is pressed'),
          'stopWorkflowChannel': PropSpec(type: 'string', defaultValue: 'workflow.stopWorkflow',
              description: 'Channel to publish when Stop All is pressed'),
          'resetWorkflowChannel': PropSpec(type: 'string', defaultValue: 'workflow.resetWorkflow',
              description: 'Channel to publish when Reset All is pressed'),
          'runStepChannel': PropSpec(type: 'string', defaultValue: 'workflow.runStep',
              description: 'Channel to publish when Run Step is pressed'),
          'stopStepChannel': PropSpec(type: 'string', defaultValue: 'workflow.stopStep',
              description: 'Channel to publish when Stop Step is pressed'),
          'resetStepChannel': PropSpec(type: 'string', defaultValue: 'workflow.resetStep',
              description: 'Channel to publish when Reset Step is pressed'),
        },
      ));

  // Test / placeholder widget
  registry.register('Placeholder', _buildPlaceholder,
      metadata: const WidgetMetadata(
        type: 'Placeholder',
        description: 'Placeholder widget for testing',
        props: {
          'label': PropSpec(type: 'string', defaultValue: 'Placeholder'),
          'color': PropSpec(type: 'string'),
        },
      ));
}

// -- Builder implementations --

Widget _buildRow(SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  final row = Row(
    mainAxisAlignment: _parseMainAxis(node.props['mainAxisAlignment']),
    crossAxisAlignment: _parseCrossAxis(node.props['crossAxisAlignment']),
    mainAxisSize: _parseMainAxisSize(node.props['mainAxisSize']),
    children: children,
  );
  if (node.props['clipBehavior'] == 'hardEdge') {
    return ClipRect(child: row);
  }
  return row;
}

Widget _buildColumn(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  return Column(
    mainAxisAlignment: _parseMainAxis(node.props['mainAxisAlignment']),
    crossAxisAlignment: _parseCrossAxis(node.props['crossAxisAlignment']),
    mainAxisSize: _parseMainAxisSize(node.props['mainAxisSize']),
    children: children,
  );
}

Widget _buildContainer(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  final bgColor = _resolveColor(node.props['color'], ctx.theme);
  final borderColor = _resolveColor(node.props['borderColor'], ctx.theme);
  final borderWidth = PropConverter.to<double>(node.props['borderWidth']) ?? 1.0;
  final borderRadius = PropConverter.to<double>(node.props['borderRadius']);
  final elevation = PropConverter.to<double>(node.props['elevation']);

  // Use BoxDecoration when border, borderRadius, or elevation is specified.
  final hasDecoration = borderColor != null || borderRadius != null || elevation != null;

  BoxDecoration? decoration;
  if (hasDecoration) {
    decoration = BoxDecoration(
      color: bgColor,
      border: borderColor != null
          ? Border.all(color: borderColor, width: borderWidth)
          : null,
      borderRadius: borderRadius != null
          ? BorderRadius.circular(borderRadius)
          : null,
      boxShadow: elevation != null && elevation > 0
          ? [
              BoxShadow(
                color: Colors.black.withAlpha((elevation * 10).clamp(0, 80).toInt()),
                blurRadius: elevation * 2,
                offset: Offset(0, elevation),
              ),
            ]
          : null,
    );
  }

  final maxWidth = PropConverter.to<double>(node.props['maxWidth']);
  final maxHeight = PropConverter.to<double>(node.props['maxHeight']);

  final wantClip = node.props['clipBehavior'] == 'hardEdge';

  return Container(
    // color and decoration are mutually exclusive in Flutter.
    color: hasDecoration ? null : bgColor,
    decoration: decoration,
    padding: _edgeInsets(node.props['padding'], spacing: ctx.theme.spacing),
    width: PropConverter.to<double>(node.props['width']),
    height: PropConverter.to<double>(node.props['height']),
    clipBehavior: (wantClip && hasDecoration) ? Clip.hardEdge : Clip.none,
    constraints: (maxWidth != null || maxHeight != null)
        ? BoxConstraints(
            maxWidth: maxWidth ?? double.infinity,
            maxHeight: maxHeight ?? double.infinity,
          )
        : null,
    child: children.isEmpty ? null : children.first,
  );
}

Widget _buildText(SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  // When no explicit color, leave null so DefaultTextStyle can cascade
  // (e.g., link color from a parent Action with openUrl intent).
  final color = _resolveColor(node.props['color'], ctx.theme);

  // Prefer textStyle (M3 slot name) over raw fontSize/fontWeight
  final textStyleName = PropConverter.to<String>(node.props['textStyle']);
  final styleDef = textStyleName != null
      ? ctx.theme.textStyles.resolve(textStyleName)
      : null;

  final TextStyle style;
  if (styleDef != null) {
    style = styleDef.toTextStyle(color: color);
  } else {
    style = TextStyle(
      fontSize: PropConverter.to<double>(node.props['fontSize']) ??
          ctx.theme.textStyles.bodyMedium.fontSize,
      color: color,
      fontWeight: _parseFontWeight(node.props['fontWeight']),
    );
  }

  final maxLines = PropConverter.to<int>(node.props['maxLines']);
  final text = PropConverter.to<String>(node.props['text']) ?? '';

  if (maxLines == null) {
    return Text(text, style: style);
  }

  // When maxLines is set, auto-show tooltip only when text is actually truncated.
  return _TruncatedText(
    text: text,
    style: style,
    maxLines: maxLines,
  );
}

/// Text widget that automatically shows a tooltip when content is truncated.
/// Always wraps in Tooltip to keep a stable widget tree — sets message to
/// empty string when not overflowing so no tooltip appears.
class _TruncatedText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final int maxLines;

  const _TruncatedText({
    required this.text,
    required this.style,
    required this.maxLines,
  });

  @override
  State<_TruncatedText> createState() => _TruncatedTextState();
}

class _TruncatedTextState extends State<_TruncatedText> {
  final _textKey = GlobalKey();
  bool _isOverflowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
  }

  @override
  void didUpdateWidget(_TruncatedText old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
  }

  void _checkOverflow() {
    final ro = _textKey.currentContext?.findRenderObject();
    if (ro is RenderBox && ro.hasSize) {
      final tp = TextPainter(
        text: TextSpan(text: widget.text, style: widget.style),
        maxLines: widget.maxLines,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: ro.size.width);
      final overflows = tp.didExceedMaxLines;
      tp.dispose();
      if (overflows != _isOverflowing && mounted) {
        setState(() => _isOverflowing = overflows);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _isOverflowing ? widget.text : '',
      waitDuration: const Duration(seconds: 3),
      child: Text(
        widget.text,
        key: _textKey,
        style: widget.style,
        maxLines: widget.maxLines,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

Widget _buildSelectableText(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  final color = _resolveColor(node.props['color'], ctx.theme) ??
      ctx.theme.colors.onSurface;

  final textStyleName = PropConverter.to<String>(node.props['textStyle']);
  final styleDef = textStyleName != null
      ? ctx.theme.textStyles.resolve(textStyleName)
      : null;

  final TextStyle style;
  if (styleDef != null) {
    style = styleDef.toTextStyle(color: color);
  } else {
    style = TextStyle(
      fontSize: PropConverter.to<double>(node.props['fontSize']) ??
          ctx.theme.textStyles.bodyMedium.fontSize,
      color: color,
      fontWeight: _parseFontWeight(node.props['fontWeight']),
    );
  }

  final maxLines = PropConverter.to<int>(node.props['maxLines']);
  final textAlign = switch (PropConverter.to<String>(node.props['textAlign'])) {
    'end' => TextAlign.end,
    'center' => TextAlign.center,
    'justify' => TextAlign.justify,
    _ => TextAlign.start,
  };

  return SelectableText(
    PropConverter.to<String>(node.props['text']) ?? '',
    style: style,
    maxLines: maxLines,
    textAlign: textAlign,
  );
}

Widget _buildMarkdown(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  final content = PropConverter.to<String>(node.props['content']) ?? '';
  final selectable = PropConverter.to<bool>(node.props['selectable']) ?? false;
  final theme = ctx.theme;

  final codeBackground = theme.colors.surfaceContainerHigh;
  final codeBorder = theme.colors.outlineVariant;

  final onSurface = theme.colors.onSurface;

  final sheet = MarkdownStyleSheet(
    // Headings
    h1: theme.textStyles.headlineLarge.toTextStyle(color: onSurface),
    h2: theme.textStyles.headlineMedium.toTextStyle(color: onSurface),
    h3: theme.textStyles.headlineSmall.toTextStyle(color: onSurface),
    h4: theme.textStyles.bodyLarge.toTextStyle(color: onSurface).copyWith(fontWeight: FontWeight.w600),
    h5: theme.textStyles.bodyMedium.toTextStyle(color: onSurface).copyWith(fontWeight: FontWeight.w600),
    h6: theme.textStyles.bodySmall.toTextStyle(color: onSurface).copyWith(fontWeight: FontWeight.w600),
    // Body
    p: theme.textStyles.bodyMedium.toTextStyle(color: onSurface),
    // Links
    a: theme.textStyles.bodyMedium.toTextStyle(color: theme.colors.primary),
    // Lists
    listBullet: theme.textStyles.bodyMedium.toTextStyle(color: onSurface),
    // Inline code
    code: theme.textStyles.bodyMedium.toTextStyle(color: onSurface).copyWith(
      fontFamily: 'monospace',
      backgroundColor: codeBackground,
    ),
    // Fenced code blocks
    codeblockDecoration: BoxDecoration(
      color: codeBackground,
      border: Border.all(color: codeBorder),
      borderRadius: BorderRadius.circular(theme.radius.sm),
    ),
    codeblockPadding: EdgeInsets.all(theme.spacing.sm),
    // Block quotes
    blockquoteDecoration: BoxDecoration(
      border: Border(
        left: BorderSide(color: theme.colors.primary, width: theme.lineWeight.emphasis),
      ),
    ),
    blockquotePadding: EdgeInsets.only(left: theme.spacing.md),
    // Table
    tableBorder: TableBorder.all(color: codeBorder),
    tableHead: theme.textStyles.bodyMedium.toTextStyle(color: onSurface).copyWith(fontWeight: FontWeight.bold),
    tableBody: theme.textStyles.bodyMedium.toTextStyle(color: onSurface),
    tableCellsPadding: EdgeInsets.all(theme.spacing.xs),
    // Horizontal rule
    horizontalRuleDecoration: BoxDecoration(
      border: Border(
        top: BorderSide(color: theme.colors.outlineVariant, width: theme.lineWeight.subtle),
      ),
    ),
    // Strong / emphasis
    strong: const TextStyle(fontWeight: FontWeight.bold),
    em: const TextStyle(fontStyle: FontStyle.italic),
  );

  if (selectable) {
    return MarkdownBody(
      data: content,
      styleSheet: sheet,
      selectable: true,
      shrinkWrap: true,
    );
  }

  return MarkdownBody(
    data: content,
    styleSheet: sheet,
    shrinkWrap: true,
  );
}

Widget _buildExpanded(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  return Expanded(
    flex: PropConverter.to<int>(node.props['flex']) ?? 1,
    child: children.isEmpty ? const SizedBox.shrink() : children.first,
  );
}

Widget _buildFlexible(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  return Flexible(
    flex: PropConverter.to<int>(node.props['flex']) ?? 1,
    fit: FlexFit.loose,
    child: children.isEmpty ? const SizedBox.shrink() : children.first,
  );
}

Widget _buildSizedBox(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  return SizedBox(
    width: PropConverter.to<double>(node.props['width']),
    height: PropConverter.to<double>(node.props['height']),
    child: children.isEmpty ? null : children.first,
  );
}

Widget _buildCenter(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  return Center(child: children.isEmpty ? null : children.first);
}

Widget _buildSpacer(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  return Spacer(flex: PropConverter.to<int>(node.props['flex']) ?? 1);
}

Widget _buildListView(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  final padding = _edgeInsets(node.props['padding'], spacing: ctx.theme.spacing);
  return SingleChildScrollView(
    padding: padding,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

Widget _buildGrid(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  final maxColumns = PropConverter.to<int>(node.props['columns']) ?? 2;
  final minColWidth =
      PropConverter.to<double>(node.props['minColumnWidth']) ?? 300.0;
  final spacing =
      _resolveSpacing(node.props['spacing'], ctx.theme.spacing) ?? 16.0;
  final runSpacing =
      _resolveSpacing(node.props['runSpacing'], ctx.theme.spacing) ?? 16.0;

  if (children.isEmpty) return const SizedBox.shrink();

  return LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final cols = (width / minColWidth).floor().clamp(1, maxColumns);

      // Distribute children into rows
      final List<Widget> rows = [];
      for (var i = 0; i < children.length; i += cols) {
        final rowChildren = <Widget>[];
        for (var j = 0; j < cols; j++) {
          if (i + j < children.length) {
            if (j > 0) rowChildren.add(SizedBox(width: spacing));
            rowChildren.add(Expanded(child: children[i + j]));
          } else {
            // Fill remaining columns with empty Expanded to keep alignment
            if (j > 0) rowChildren.add(SizedBox(width: spacing));
            rowChildren.add(const Expanded(child: SizedBox.shrink()));
          }
        }
        if (rows.isNotEmpty) rows.add(SizedBox(height: runSpacing));
        rows.add(IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rowChildren,
          ),
        ));
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: rows,
      );
    },
  );
}

Widget _buildWrap(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  final spacing =
      _resolveSpacing(node.props['spacing'], ctx.theme.spacing) ??
          ctx.theme.spacing.sm;
  final runSpacing =
      _resolveSpacing(node.props['runSpacing'], ctx.theme.spacing) ??
          ctx.theme.spacing.sm;
  final alignStr =
      PropConverter.to<String>(node.props['alignment']) ?? 'start';
  final alignment = switch (alignStr) {
    'end' => WrapAlignment.end,
    'center' => WrapAlignment.center,
    'spaceBetween' => WrapAlignment.spaceBetween,
    'spaceAround' => WrapAlignment.spaceAround,
    'spaceEvenly' => WrapAlignment.spaceEvenly,
    _ => WrapAlignment.start,
  };
  return Wrap(
    spacing: spacing,
    runSpacing: runSpacing,
    alignment: alignment,
    children: children,
  );
}

// ---------------------------------------------------------------------------
// FormDialog — modal overlay dialog rendering children as SDUI content
// ---------------------------------------------------------------------------

Widget _buildFormDialog(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  return _FormDialog(
    key: ValueKey('dialog-${node.id}'),
    node: node,
    context: ctx,
    children: children,
  );
}

class _FormDialog extends StatefulWidget {
  final SduiNode node;
  final SduiRenderContext context;
  final List<Widget> children;

  const _FormDialog({
    super.key,
    required this.node,
    required this.context,
    required this.children,
  });

  @override
  State<_FormDialog> createState() => _FormDialogState();
}

class _FormDialogState extends State<_FormDialog> {
  bool _visible = true;
  StreamSubscription<EventPayload>? _visibilitySub;

  @override
  void initState() {
    super.initState();
    _visible = PropConverter.to<bool>(widget.node.props['visible']) ?? true;

    // Listen for visibility changes on input.<id>.changed channel
    _visibilitySub = widget.context.eventBus
        .subscribe('input.${widget.node.id}.changed')
        .listen((event) {
      final val = event.data['value'];
      if (val is bool) {
        setState(() => _visible = val);
      }
    });
  }

  @override
  void dispose() {
    _visibilitySub?.cancel();
    super.dispose();
  }

  void _dismiss() {
    final modal = PropConverter.to<bool>(widget.node.props['modal']) ?? true;
    if (!modal) {
      setState(() => _visible = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    final theme = widget.context.theme;
    final colorScheme = Theme.of(context).colorScheme;
    final title = PropConverter.to<String>(widget.node.props['title']);
    final modal = PropConverter.to<bool>(widget.node.props['modal']) ?? true;
    final width = PropConverter.to<double>(widget.node.props['width']) ?? 420.0;
    final screenSize = MediaQuery.of(context).size;

    // Use an Overlay to float above all content
    return Stack(
      children: [
        // Scrim — minimal opacity, click to dismiss if not modal
        Positioned.fill(
          child: GestureDetector(
            onTap: modal ? null : _dismiss,
            child: Container(color: colorScheme.scrim.withAlpha(20)),
          ),
        ),
        // Dialog card — centered on screen
        Positioned(
          left: (screenSize.width - width) / 2,
          top: screenSize.height * 0.1,
          child: Material(
            elevation: theme.elevation.high,
            borderRadius: BorderRadius.circular(theme.radius.lg),
            color: colorScheme.surface,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: width,
                maxHeight: screenSize.height * 0.8,
              ),
              child: SizedBox(
                width: width,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    if (title != null)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          theme.spacing.md, theme.spacing.md,
                          theme.spacing.md, theme.spacing.sm,
                        ),
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    // Children — scrollable content area
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: theme.spacing.md,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: widget.children,
                        ),
                      ),
                    ),
                    SizedBox(height: theme.spacing.md),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Widget _buildCard(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  return Card(
    elevation: PropConverter.to<double>(node.props['elevation']) ??
        ctx.theme.elevation.low,
    color: _resolveColor(node.props['color'], ctx.theme) ??
        ctx.theme.colors.surface,
    child: children.isEmpty ? null : children.first,
  );
}

Widget _buildDashboardCard(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  final theme = ctx.theme;
  final title = PropConverter.to<String>(node.props['title']) ?? '';
  final iconName = PropConverter.to<String>(node.props['icon']);
  final footerSlot = PropConverter.to<int>(node.props['footerSlot']) ?? -1;
  final searchable = node.props['searchable'] == true || node.props['searchable'] == 'true';

  // Page size selector
  final rawPageSizes = node.props['pageSizes'];
  final pageSizes = rawPageSizes is List
      ? rawPageSizes.map((e) => PropConverter.to<int>(e) ?? 0).where((e) => e > 0).toList()
      : <int>[];
  final pageSizeChannel = PropConverter.to<String>(node.props['pageSizeChannel']);
  final defaultPageSize = PropConverter.to<int>(node.props['defaultPageSize'])
      ?? (pageSizes.isNotEmpty ? pageSizes.first : 0);

  // Separate footer child if specified
  Widget? footer;
  final bodyChildren = List<Widget>.from(children);
  if (pageSizes.isEmpty && footerSlot >= 0 && footerSlot < bodyChildren.length) {
    footer = bodyChildren.removeAt(footerSlot);
  } else if (pageSizes.isNotEmpty && footerSlot >= 0 && footerSlot < bodyChildren.length) {
    // pageSizes replaces the manual footer — remove the old one
    bodyChildren.removeAt(footerSlot);
  }

  // Resolve icon
  final iconData = iconName != null ? _iconMap[iconName] : null;
  final iconWidget = iconData != null ? Icon(iconData) : null;

  // Filter channel scoped to this card
  final filterChannel = 'card.${node.id}.filter';

  return _DashboardCardWidget(
    theme: theme,
    title: title,
    iconWidget: iconWidget,
    searchable: searchable,
    filterChannel: filterChannel,
    eventBus: ctx.eventBus,
    bodyChildren: bodyChildren,
    footer: footer,
    pageSizes: pageSizes,
    pageSizeChannel: pageSizeChannel,
    defaultPageSize: defaultPageSize,
  );
}

class _DashboardCardWidget extends StatefulWidget {
  final SduiTheme theme;
  final String title;
  final Widget? iconWidget;
  final bool searchable;
  final String filterChannel;
  final EventBus eventBus;
  final List<Widget> bodyChildren;
  final Widget? footer;
  final List<int> pageSizes;
  final String? pageSizeChannel;
  final int defaultPageSize;

  const _DashboardCardWidget({
    required this.theme,
    required this.title,
    required this.iconWidget,
    required this.searchable,
    required this.filterChannel,
    required this.eventBus,
    required this.bodyChildren,
    required this.footer,
    this.pageSizes = const [],
    this.pageSizeChannel,
    this.defaultPageSize = 0,
  });

  @override
  State<_DashboardCardWidget> createState() => _DashboardCardWidgetState();
}

class _DashboardCardWidgetState extends State<_DashboardCardWidget> {
  bool _searchOpen = false;
  final _searchController = TextEditingController();
  late int _activePageSize;
  StreamSubscription<EventPayload>? _pageSizeSub;

  @override
  void initState() {
    super.initState();
    _activePageSize = widget.defaultPageSize;
    _subscribePageSize();
  }

  void _subscribePageSize() {
    final channel = widget.pageSizeChannel;
    if (channel == null || channel.isEmpty || widget.pageSizes.isEmpty) return;
    _pageSizeSub = widget.eventBus.subscribe(channel).listen((event) {
      final value = PropConverter.to<int>(event.data['value']);
      if (value != null && value != _activePageSize && mounted) {
        setState(() => _activePageSize = value);
      }
    });
  }

  void _setPageSize(int size) {
    final channel = widget.pageSizeChannel;
    if (channel == null) return;
    setState(() => _activePageSize = size);
    widget.eventBus.publish(
      channel,
      EventPayload(
        type: 'onTap',
        sourceWidgetId: 'page-size-selector',
        data: {'value': size, '_channel': channel},
      ),
    );
  }

  @override
  void dispose() {
    _pageSizeSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    widget.eventBus.publish(
      widget.filterChannel,
      EventPayload(
        type: 'filter',
        sourceWidgetId: widget.filterChannel,
        data: {'query': query.trim().toLowerCase()},
      ),
    );
  }

  bool get _hasActiveFilter => _searchController.text.trim().isNotEmpty;

  void _toggleSearch() {
    if (_searchOpen && _hasActiveFilter) {
      // Search open with active filter — clear and close
      _closeSearch();
    } else if (_searchOpen) {
      // Search open, no filter — just close
      setState(() => _searchOpen = false);
    } else {
      // Closed — open
      setState(() => _searchOpen = true);
    }
  }

  void _closeSearch() {
    _searchController.clear();
    _onSearchChanged('');
    setState(() => _searchOpen = false);
  }


  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    return Container(
      decoration: BoxDecoration(
        color: theme.colors.surface,
        border: Border.all(
          color: theme.colors.outline,
          width: theme.lineWeight.subtle,
        ),
        borderRadius: BorderRadius.circular(theme.radius.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            offset: const Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.md,
              vertical: theme.spacing.sm,
            ),
            decoration: BoxDecoration(
              color: theme.colors.surfaceContainer,
              border: Border(
                bottom: BorderSide(
                  color: theme.colors.outlineVariant,
                  width: theme.lineWeight.subtle,
                ),
              ),
            ),
            child: Row(
              children: [
                if (widget.iconWidget != null) ...[
                  IconTheme(
                    data: IconThemeData(
                      size: theme.iconSize.sm,
                      color: theme.colors.primary,
                    ),
                    child: widget.iconWidget!,
                  ),
                  SizedBox(width: theme.spacing.sm),
                ],
                Expanded(
                  child: Text(
                    widget.title,
                    style: theme.textStyles.headlineSmall
                        .toTextStyle(color: theme.colors.onSurface),
                  ),
                ),
                if (widget.searchable)
                  GestureDetector(
                    onTap: _toggleSearch,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Icon(
                        _searchOpen ? Icons.close : Icons.search,
                        size: theme.iconSize.sm,
                        color: _searchOpen || _hasActiveFilter
                            ? theme.colors.primary
                            : theme.colors.onSurfaceMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Inline search row — closes on focus loss if empty
          if (_searchOpen)
            Padding(
              padding: EdgeInsets.fromLTRB(
                theme.spacing.md, theme.spacing.sm,
                theme.spacing.md, 0,
              ),
              child: Focus(
                onFocusChange: (hasFocus) {
                  if (!hasFocus && !_hasActiveFilter && mounted) {
                    setState(() => _searchOpen = false);
                  }
                },
                child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _onSearchChanged,
                style: theme.textStyles.bodySmall
                    .toTextStyle(color: theme.colors.onSurface),
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: theme.textStyles.bodySmall
                      .toTextStyle(color: theme.colors.onSurfaceMuted),
                  prefixIcon: Icon(Icons.search,
                      size: theme.iconSize.sm, color: theme.colors.onSurfaceMuted),
                  prefixIconConstraints:
                      BoxConstraints(minWidth: theme.window.toolbarButtonSize, minHeight: theme.window.toolbarButtonSize),
                  suffixIcon: _hasActiveFilter
                      ? GestureDetector(
                          onTap: _closeSearch,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Icon(Icons.close,
                                size: theme.iconSize.sm, color: theme.colors.onSurfaceMuted),
                          ),
                        )
                      : null,
                  suffixIconConstraints:
                      BoxConstraints(minWidth: theme.window.toolbarButtonSize, minHeight: theme.window.toolbarButtonSize),
                  isDense: true,
                ),
              ),
              ),
            ),
          // Body
          ...widget.bodyChildren,
          // Footer — page size selector or custom footer
          if (widget.pageSizes.isNotEmpty) ...[
            Divider(
              height: 1,
              thickness: theme.lineWeight.subtle,
              color: theme.colors.outlineVariant,
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing.md,
                vertical: theme.spacing.xs,
              ),
              child: Row(
                children: [
                  Text(
                    'Show:',
                    style: theme.textStyles.bodySmall
                        .toTextStyle(color: theme.colors.onSurfaceMuted),
                  ),
                  SizedBox(width: theme.spacing.xs),
                  for (var i = 0; i < widget.pageSizes.length; i++) ...[
                    if (i > 0) SizedBox(width: theme.spacing.sm),
                    _buildPageSizeButton(widget.pageSizes[i], theme),
                  ],
                ],
              ),
            ),
          ] else if (widget.footer != null) ...[
            Divider(
              height: 1,
              thickness: theme.lineWeight.subtle,
              color: theme.colors.outlineVariant,
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing.md,
                vertical: theme.spacing.xs,
              ),
              child: widget.footer,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPageSizeButton(int size, SduiTheme theme) {
    final isActive = size == _activePageSize;
    return GestureDetector(
      onTap: () => _setPageSize(size),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.xs,
            vertical: theme.spacing.xs / 2,
          ),
          decoration: isActive
              ? BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: theme.colors.primary,
                      width: theme.lineWeight.standard,
                    ),
                  ),
                )
              : null,
          child: Text(
            '$size',
            style: (isActive
                    ? theme.textStyles.labelSmall
                    : theme.textStyles.bodySmall)
                .toTextStyle(
              color: isActive
                  ? theme.colors.primary
                  : theme.colors.onSurfaceMuted,
            ),
          ),
        ),
      ),
    );
  }
}

Widget _buildPadding(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  final bgColor = _resolveColor(node.props['color'], ctx.theme);
  final child = children.isEmpty ? null : children.first;
  final padded = Padding(
    padding: _edgeInsets(node.props['padding'], spacing: ctx.theme.spacing) ?? EdgeInsets.zero,
    child: child,
  );
  if (bgColor != null) {
    return ColoredBox(color: bgColor, child: padded);
  }
  return padded;
}

Widget _buildPlaceholder(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  final label = PropConverter.to<String>(node.props['label']) ?? 'Placeholder';
  final color = _resolveColor(node.props['color'], ctx.theme) ??
      ctx.theme.colors.primary;
  return Container(
    decoration: BoxDecoration(
      color: color.withAlpha(ctx.theme.opacity.subtle),
      border: Border.all(color: color.withAlpha(ctx.theme.opacity.light)),
      borderRadius: BorderRadius.circular(ctx.theme.radius.md),
    ),
    padding: EdgeInsets.all(ctx.theme.spacing.md),
    child: Center(
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: ctx.theme.textStyles.headlineSmall.fontSize),
      ),
    ),
  );
}

Widget _buildLoadingIndicator(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  final variant = PropConverter.to<String>(node.props['variant']) ?? 'spinner';
  final width = PropConverter.to<double>(node.props['width']);
  final height = PropConverter.to<double>(node.props['height']);
  final color = _resolveColor(node.props['color'], ctx.theme);
  final text = PropConverter.to<String>(node.props['text']);
  final theme = ctx.theme;

  Widget indicator;
  switch (variant) {
    case 'linear':
      indicator = SizedBox(
        width: width,
        child: LinearProgressIndicator(
          color: color ?? theme.colors.primary,
          minHeight: height ?? ctx.theme.lineWeight.emphasis,
        ),
      );
    case 'skeleton':
      indicator = _SkeletonPulse(
        width: width ?? 200,
        height: height ?? 16,
        color: color ?? theme.colors.onSurfaceMuted,
        theme: theme,
      );
    default: // spinner
      indicator = SizedBox(
        width: width ?? 24,
        height: height ?? 24,
        child: CircularProgressIndicator(
          strokeWidth: theme.lineWeight.emphasis,
          color: color ?? theme.colors.primary,
        ),
      );
  }

  if (text != null) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        indicator,
        SizedBox(height: theme.spacing.sm),
        Text(text, style: TextStyle(
          color: color ?? theme.colors.onSurfaceVariant,
          fontSize: theme.textStyles.bodySmall.fontSize,
        )),
      ],
    );
  }
  return indicator;
}

class _SkeletonPulse extends StatefulWidget {
  final double width;
  final double height;
  final Color color;
  final SduiTheme theme;

  const _SkeletonPulse({
    required this.width,
    required this.height,
    required this.color,
    required this.theme,
  });

  @override
  State<_SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<_SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.theme.animation.slow.inMilliseconds * 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.color.withAlpha((50 + (_controller.value * 50)).toInt()),
            borderRadius: BorderRadius.circular(widget.theme.radius.sm),
          ),
        );
      },
    );
  }
}

/// Resolve an asset URL: if [catalogBaseUrl] is set and is not already a
/// substring of [url], prefix [url] with the base.  Handles both absolute
/// URLs (which will contain their own scheme/host, never a substring of the
/// base) and relative paths that need the base prepended.
String _resolveAssetUrl(String url, String? catalogBaseUrl) {
  if (catalogBaseUrl == null || catalogBaseUrl.isEmpty) return url;
  if (url.contains(catalogBaseUrl)) return url;
  final base = catalogBaseUrl.endsWith('/')
      ? catalogBaseUrl.substring(0, catalogBaseUrl.length - 1)
      : catalogBaseUrl;
  final path = url.startsWith('/') ? url : '/$url';
  return '$base$path';
}

// -- Image, Tooltip, ProgressBar builders --

Widget _buildImage(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  final rawSrc = PropConverter.to<String>(node.props['src']) ?? '';
  final src = rawSrc.isEmpty ? rawSrc : _resolveAssetUrl(rawSrc, ctx.catalogBaseUrl);
  final width = PropConverter.to<double>(node.props['width']);
  final height = PropConverter.to<double>(node.props['height']);
  final errorText =
      PropConverter.to<String>(node.props['errorText']) ?? 'Image failed to load';
  final fit = switch (PropConverter.to<String>(node.props['fit'])) {
    'cover' => BoxFit.cover,
    'fill' => BoxFit.fill,
    'fitWidth' => BoxFit.fitWidth,
    'fitHeight' => BoxFit.fitHeight,
    'none' => BoxFit.none,
    'scaleDown' => BoxFit.scaleDown,
    _ => BoxFit.contain,
  };

  // Placeholder/loading/error widgets need bounded constraints to avoid
  // infinite-width errors when placed inside a Row. Use height as fallback
  // width so Center/Column children get a finite box.
  final placeholderWidth = width ?? height;
  final placeholderHeight = height ?? width;

  if (src.isEmpty) {
    return SizedBox(
      width: placeholderWidth,
      height: placeholderHeight,
      child: Center(
        child: Icon(FontAwesomeIcons.image,
            size: (placeholderHeight ?? 24) * 0.6,
            color: ctx.theme.colors.onSurfaceMuted),
      ),
    );
  }

  return Image.network(
    src,
    width: width,
    height: height,
    fit: fit,
    errorBuilder: (context, error, stackTrace) {
      debugPrint('[Image] Failed to load $src: $error');
      return SizedBox(
        width: placeholderWidth,
        height: placeholderHeight,
        child: Tooltip(
          message: errorText,
          child: Icon(FontAwesomeIcons.image,
              size: (placeholderHeight ?? 24) * 0.6,
              color: ctx.theme.colors.error),
        ),
      );
    },
    loadingBuilder: (context, child, progress) {
      if (progress == null) return child;
      return SizedBox(
        width: placeholderWidth,
        height: placeholderHeight,
        child: Center(
          child: SizedBox(
            width: (placeholderHeight ?? 24) * 0.5,
            height: (placeholderHeight ?? 24) * 0.5,
            child: CircularProgressIndicator(
              strokeWidth: ctx.theme.lineWeight.emphasis,
              color: ctx.theme.colors.primary,
              value: progress.expectedTotalBytes != null
                  ? progress.cumulativeBytesLoaded /
                      progress.expectedTotalBytes!
                  : null,
            ),
          ),
        ),
      );
    },
  );
}

Widget _buildTooltip(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  final message = PropConverter.to<String>(node.props['message']) ?? '';
  return Tooltip(
    message: message,
    child: children.isEmpty ? const SizedBox.shrink() : children.first,
  );
}

Widget _buildProgressBar(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  final value = PropConverter.to<double>(node.props['value']);
  final variant = PropConverter.to<String>(node.props['variant']) ?? 'linear';
  final color =
      _resolveColor(node.props['color'], ctx.theme) ?? ctx.theme.colors.primary;
  final bgColor = _resolveColor(node.props['backgroundColor'], ctx.theme);
  final text = PropConverter.to<String>(node.props['text']);

  Widget indicator;
  if (variant == 'circular') {
    indicator = SizedBox(
      width: ctx.theme.window.spinnerSize,
      height: ctx.theme.window.spinnerSize,
      child: CircularProgressIndicator(
        value: value,
        strokeWidth: ctx.theme.lineWeight.vizHighlight,
        color: color,
        backgroundColor: bgColor,
      ),
    );
  } else {
    indicator = LinearProgressIndicator(
      value: value,
      color: color,
      backgroundColor: bgColor,
      minHeight: ctx.theme.lineWeight.emphasis,
    );
  }

  if (text != null) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text,
            style: TextStyle(
              color: ctx.theme.colors.onSurfaceVariant,
              fontSize: ctx.theme.textStyles.bodySmall.fontSize,
            )),
        SizedBox(height: ctx.theme.spacing.xs),
        indicator,
      ],
    );
  }
  return indicator;
}

// -- Interactive widget builders --

Widget _buildTextField(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  return _SduiTextField(
    node: node,
    context: ctx,
  );
}

Widget _buildElevatedButton(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  final text = PropConverter.to<String>(node.props['text']) ?? '';
  final channel = PropConverter.to<String>(node.props['channel']) ?? '';
  final payload = node.props['payload'] as Map<String, dynamic>? ?? {};
  final enabled = PropConverter.to<bool>(node.props['enabled']) ?? true;
  final color = _resolveColor(node.props['color'], ctx.theme);

  final btn = ctx.theme.button;
  return ElevatedButton(
    onPressed: enabled && channel.isNotEmpty
        ? () => ctx.eventBus.publish(
              channel,
              EventPayload(type: 'action', sourceWidgetId: node.id, data: payload),
            )
        : null,
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      minimumSize: Size(0, ctx.theme.controlHeight.md),
      padding: EdgeInsets.symmetric(horizontal: btn.paddingH, vertical: btn.paddingV),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(btn.borderRadius)),
    ),
    child: Text(text),
  );
}

Widget _buildOutlinedButton(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  final text = PropConverter.to<String>(node.props['text']) ?? '';
  final channel = PropConverter.to<String>(node.props['channel']) ?? '';
  final payload = node.props['payload'] as Map<String, dynamic>? ?? {};
  final enabled = PropConverter.to<bool>(node.props['enabled']) ?? true;
  final color = _resolveColor(node.props['color'], ctx.theme);

  final btn = ctx.theme.button;
  final borderColor = color ?? ctx.theme.colors.primary;
  return OutlinedButton(
    onPressed: enabled && channel.isNotEmpty
        ? () => ctx.eventBus.publish(
              channel,
              EventPayload(type: 'action', sourceWidgetId: node.id, data: payload),
            )
        : null,
    style: OutlinedButton.styleFrom(
      foregroundColor: borderColor,
      minimumSize: Size(0, ctx.theme.controlHeight.md),
      side: BorderSide(color: enabled ? borderColor : borderColor.withAlpha(ctx.theme.opacity.disabled), width: btn.outlinedBorderWidth),
      padding: EdgeInsets.symmetric(horizontal: btn.paddingH, vertical: btn.paddingV),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(btn.borderRadius)),
    ),
    child: Text(text),
  );
}

Widget _buildTextButton(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  final text = PropConverter.to<String>(node.props['text']) ?? '';
  final channel = PropConverter.to<String>(node.props['channel']) ?? '';
  final payload = node.props['payload'] as Map<String, dynamic>? ?? {};
  final enabled = PropConverter.to<bool>(node.props['enabled']) ?? true;
  final color = _resolveColor(node.props['color'], ctx.theme);

  final btn = ctx.theme.button;
  return TextButton(
    onPressed: enabled && channel.isNotEmpty
        ? () => ctx.eventBus.publish(
              channel,
              EventPayload(type: 'action', sourceWidgetId: node.id, data: payload),
            )
        : null,
    style: TextButton.styleFrom(
      foregroundColor: color,
      minimumSize: Size(0, ctx.theme.controlHeight.md),
      padding: EdgeInsets.symmetric(horizontal: btn.paddingH, vertical: btn.paddingV),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(btn.borderRadius)),
    ),
    child: Text(text),
  );
}

Widget _buildIconButton(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  final iconName = PropConverter.to<String>(node.props['icon']) ?? '';
  final channel = PropConverter.to<String>(node.props['channel']) ?? '';
  final payload = node.props['payload'] as Map<String, dynamic>? ?? {};
  final tooltip = PropConverter.to<String>(node.props['tooltip']);
  final enabled = PropConverter.to<bool>(node.props['enabled']) ?? true;
  final variant = PropConverter.to<String>(node.props['variant']);
  final weight = PropConverter.to<String>(node.props['weight']) ?? 'solid';
  final stateChannel = PropConverter.to<String>(node.props['stateChannel']);

  final iconData = _resolveIcon(iconName, weight) ?? FontAwesomeIcons.circleQuestion;

  void onTap() {
    if (channel.isNotEmpty) {
      ctx.eventBus.publish(
        channel,
        EventPayload(type: 'action', sourceWidgetId: node.id, data: payload),
      );
    }
  }

  // Toolbar variants use window tokens for styled containers.
  if (variant == 'toolbar-primary' || variant == 'toolbar-secondary') {
    final wt = ctx.theme.window;
    final isPrimary = variant == 'toolbar-primary';
    final iconSize = PropConverter.to<double>(node.props['size']) ?? wt.toolbarButtonIconSize;

    // If stateChannel is set, use reactive version that updates icon/tooltip
    if (stateChannel != null && stateChannel.isNotEmpty) {
      return _ReactiveToolbarIconButton(
        key: ValueKey('toolbar-ib-${node.id}'),
        initialIcon: iconData,
        iconSize: iconSize,
        isPrimary: isPrimary,
        enabled: enabled,
        initialTooltip: tooltip ?? '',
        onTap: onTap,
        theme: ctx.theme,
        eventBus: ctx.eventBus,
        stateChannel: stateChannel,
      );
    }

    return _ToolbarIconButton(
      key: ValueKey('toolbar-ib-${node.id}'),
      icon: iconData,
      iconSize: iconSize,
      isPrimary: isPrimary,
      enabled: enabled,
      tooltip: tooltip ?? '',
      onTap: onTap,
      theme: ctx.theme,
    );
  }

  // Default: bare icon button (backward compatible).
  final size = PropConverter.to<double>(node.props['size']) ?? ctx.theme.iconSize.md;
  final color = _resolveColor(node.props['color'], ctx.theme) ??
      ctx.theme.colors.onSurface;

  return IconButton(
    icon: Icon(iconData, size: size, color: enabled ? color : color.withAlpha(ctx.theme.opacity.disabled)),
    tooltip: tooltip,
    onPressed: enabled ? onTap : null,
  );
}

/// Toolbar-styled icon button with hover, primary/secondary variants,
/// and full theme token integration.
class _ToolbarIconButton extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final bool isPrimary;
  final bool enabled;
  final String tooltip;
  final VoidCallback onTap;
  final SduiTheme theme;

  const _ToolbarIconButton({
    super.key,
    required this.icon,
    required this.iconSize,
    required this.isPrimary,
    required this.enabled,
    required this.tooltip,
    required this.onTap,
    required this.theme,
  });

  @override
  State<_ToolbarIconButton> createState() => _ToolbarIconButtonState();
}

class _ToolbarIconButtonState extends State<_ToolbarIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final wt = t.window;
    final primary = t.colors.primary;

    final Color bg;
    final Color fg;
    final Border? border;

    if (!widget.enabled) {
      bg = Colors.transparent;
      fg = t.colors.onSurface.withAlpha(t.opacity.disabled);
      border = Border.all(color: t.colors.outline.withAlpha(t.opacity.disabled), width: wt.toolbarButtonBorderWidth);
    } else if (widget.isPrimary) {
      bg = _hovered
          ? HSLColor.fromColor(primary).withLightness(
              (HSLColor.fromColor(primary).lightness - 0.08).clamp(0, 1)).toColor()
          : primary;
      fg = t.colors.onPrimary;
      border = null;
    } else {
      bg = _hovered ? primary.withAlpha(t.opacity.subtle) : Colors.transparent;
      fg = primary;
      border = Border.all(color: primary, width: wt.toolbarButtonBorderWidth);
    }

    final button = MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: t.animation.fast,
          width: wt.toolbarButtonSize,
          height: wt.toolbarButtonSize,
          decoration: BoxDecoration(
            color: bg,
            border: border,
            borderRadius: BorderRadius.circular(wt.toolbarButtonRadius),
          ),
          child: Center(
            child: Icon(widget.icon, size: widget.iconSize, color: fg),
          ),
        ),
      ),
    );

    if (widget.tooltip.isNotEmpty) {
      return Tooltip(message: widget.tooltip, child: button);
    }
    return button;
  }
}

/// Reactive toolbar icon button that listens to a state channel for icon/tooltip updates.
class _ReactiveToolbarIconButton extends StatefulWidget {
  final IconData initialIcon;
  final double iconSize;
  final bool isPrimary;
  final bool enabled;
  final String initialTooltip;
  final VoidCallback onTap;
  final SduiTheme theme;
  final EventBus eventBus;
  final String stateChannel;

  const _ReactiveToolbarIconButton({
    super.key,
    required this.initialIcon,
    required this.iconSize,
    required this.isPrimary,
    required this.enabled,
    required this.initialTooltip,
    required this.onTap,
    required this.theme,
    required this.eventBus,
    required this.stateChannel,
  });

  @override
  State<_ReactiveToolbarIconButton> createState() => _ReactiveToolbarIconButtonState();
}

class _ReactiveToolbarIconButtonState extends State<_ReactiveToolbarIconButton> {
  late IconData _icon;
  late String _tooltip;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _icon = widget.initialIcon;
    _tooltip = widget.initialTooltip;
    _sub = widget.eventBus.subscribe(widget.stateChannel).listen((event) {
      if (!mounted) return;
      setState(() {
        final iconName = event.data['icon'] as String?;
        if (iconName != null) {
          _icon = _iconMap[iconName] ?? widget.initialIcon;
        }
        final tip = event.data['tooltip'] as String?;
        if (tip != null) _tooltip = tip;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ToolbarIconButton(
      icon: _icon,
      iconSize: widget.iconSize,
      isPrimary: widget.isPrimary,
      enabled: widget.enabled,
      tooltip: _tooltip,
      onTap: widget.onTap,
      theme: widget.theme,
    );
  }
}

Widget _buildPopupMenu(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  final multiSelect = PropConverter.to<bool>(node.props['multiSelect']) ?? false;
  final iconOnly = PropConverter.to<bool>(node.props['iconOnly']) ?? false;

  // MultiSelect mode: checkbox list that stays open
  if (multiSelect) {
    return _MultiSelectPopupMenu(
      key: ValueKey('ms-popup-${node.id}'),
      node: node,
      ctx: ctx,
    );
  }

  // For iconOnly mode, use stateful widget to track selected item and update trigger icon
  if (iconOnly) {
    return _IconOnlyPopupMenu(
      key: ValueKey('popup-${node.id}'),
      node: node,
      ctx: ctx,
    );
  }

  final iconName = PropConverter.to<String>(node.props['icon']) ?? 'more_vert';
  final iconSize = PropConverter.to<double>(node.props['iconSize']) ?? ctx.theme.iconSize.md;
  final iconColor = _resolveColor(node.props['iconColor'], ctx.theme) ??
      ctx.theme.colors.onSurface;
  final tooltip = PropConverter.to<String>(node.props['tooltip']);
  final variant = PropConverter.to<String>(node.props['variant']);
  final channel = PropConverter.to<String>(node.props['channel']) ?? '';
  final rawItems = node.props['items'] as List<dynamic>? ?? [];

  final iconData = _iconMap[iconName] ?? FontAwesomeIcons.ellipsisVertical;

  final entries = <PopupMenuEntry<String>>[];
  for (final item in rawItems) {
    if (item is! Map) continue;
    final m = Map<String, dynamic>.from(item);
    if (PropConverter.to<bool>(m['divider']) == true) {
      entries.add(const PopupMenuDivider());
      continue;
    }
    final value = PropConverter.to<String>(m['value']) ?? '';
    final label = PropConverter.to<String>(m['label']) ??
        PropConverter.to<String>(m['tooltip']) ?? value;
    final itemIconName = PropConverter.to<String>(m['icon']);
    final itemIcon = itemIconName != null
        ? (_resolveIcon(itemIconName, 'solid') ?? _resolveIcon(itemIconName, 'regular'))
        : null;
    final itemIconColor = _resolveColor(m['iconColor'], ctx.theme);

    entries.add(PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          if (itemIcon != null) ...[
            Icon(itemIcon, size: ctx.theme.iconSize.sm,
                color: itemIconColor ?? ctx.theme.colors.primary),
            SizedBox(width: ctx.theme.spacing.sm),
          ],
          Text(label, style: TextStyle(fontSize: ctx.theme.textStyles.bodySmall.fontSize)),
        ],
      ),
    ));
  }

  void onSelected(String value) {
    if (channel.isNotEmpty) {
      ctx.eventBus.publish(
        channel,
        EventPayload(
          type: 'menu.select',
          sourceWidgetId: node.id,
          data: {'value': value},
        ),
      );
    }
  }

  // When children are provided, use the first child as the trigger widget.
  if (children.isNotEmpty) {
    return PopupMenuButton<String>(
      tooltip: tooltip ?? '',
      itemBuilder: (_) => entries,
      onSelected: onSelected,
      child: children.first,
    );
  }

  // Toolbar variant: use _ToolbarIconButton styling as trigger
  if (variant == 'toolbar-primary' || variant == 'toolbar-secondary') {
    return _ToolbarPopupMenu(
      key: ValueKey('tb-popup-${node.id}'),
      iconData: iconData,
      variant: variant!,
      tooltip: tooltip ?? '',
      entries: entries,
      onSelected: onSelected,
      theme: ctx.theme,
    );
  }

  return PopupMenuButton<String>(
    icon: Icon(iconData, size: iconSize, color: iconColor),
    tooltip: tooltip ?? '',
    itemBuilder: (_) => entries,
    onSelected: onSelected,
  );
}

/// Stateful icon-only PopupMenu that updates its trigger icon to match
/// the selected item (e.g., filter dropdown showing active filter icon).
class _IconOnlyPopupMenu extends StatefulWidget {
  final SduiNode node;
  final SduiRenderContext ctx;
  const _IconOnlyPopupMenu({super.key, required this.node, required this.ctx});
  @override
  State<_IconOnlyPopupMenu> createState() => _IconOnlyPopupMenuState();
}

class _IconOnlyPopupMenuState extends State<_IconOnlyPopupMenu> {
  String _selectedValue = '';

  List<Map<String, dynamic>> get _items =>
      (widget.node.props['items'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();

  Map<String, dynamic>? get _selectedItem {
    if (_selectedValue.isEmpty && _items.isNotEmpty) return _items.first;
    return _items.where((m) => m['value'] == _selectedValue).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final ctx = widget.ctx;
    final node = widget.node;
    final channel = PropConverter.to<String>(node.props['channel']) ?? '';
    final tooltip = PropConverter.to<String>(node.props['tooltip']) ?? '';

    // Build entries
    final entries = <PopupMenuEntry<String>>[];
    for (final m in _items) {
      final value = PropConverter.to<String>(m['value']) ?? '';
      final itemIconName = PropConverter.to<String>(m['icon']);
      final itemIcon = itemIconName != null
          ? (_resolveIcon(itemIconName, 'solid') ?? _resolveIcon(itemIconName, 'regular'))
          : null;
      final itemIconColor = _resolveColor(m['iconColor'], ctx.theme);
      final itemTooltip = PropConverter.to<String>(m['tooltip']);
      final label = PropConverter.to<String>(m['label']) ?? itemTooltip ?? value;

      Widget child;
      if (itemIcon != null) {
        child = Center(child: Icon(itemIcon, size: ctx.theme.iconSize.sm,
            color: itemIconColor ?? ctx.theme.colors.onSurfaceVariant));
      } else {
        child = Center(child: Text(label, style: TextStyle(
            fontSize: ctx.theme.textStyles.bodySmall.fontSize,
            color: itemIconColor ?? ctx.theme.colors.primary)));
      }
      if (itemTooltip != null) {
        child = Tooltip(message: itemTooltip, child: child);
      }
      entries.add(PopupMenuItem<String>(value: value, height: ctx.theme.controlHeight.md, child: child));
    }

    // Resolve trigger icon from selected item
    final sel = _selectedItem;
    final triggerIconName = PropConverter.to<String>(sel?['icon']) ??
        PropConverter.to<String>(node.props['icon']) ?? 'filter_list';
    final triggerIcon = _resolveIcon(triggerIconName, 'solid') ??
        _resolveIcon(triggerIconName, 'regular') ?? FontAwesomeIcons.filter;
    final triggerColor = _resolveColor(sel?['iconColor'], ctx.theme) ??
        _resolveColor(node.props['iconColor'], ctx.theme) ??
        ctx.theme.colors.primary;
    final triggerSize = PropConverter.to<double>(node.props['iconSize']) ??
        ctx.theme.iconSize.md;

    return PopupMenuButton<String>(
      icon: Icon(triggerIcon, size: triggerSize, color: triggerColor),
      tooltip: tooltip,
      constraints: BoxConstraints(minWidth: ctx.theme.window.toolbarHeight, maxWidth: ctx.theme.window.toolbarHeight + ctx.theme.spacing.sm),
      itemBuilder: (_) => entries,
      onSelected: (value) {
        setState(() => _selectedValue = value);
        if (channel.isNotEmpty) {
          ctx.eventBus.publish(channel,
            EventPayload(type: 'menu.select', sourceWidgetId: node.id,
                data: {'value': value}));
        }
      },
    );
  }
}

/// PopupMenu with toolbar-variant styled trigger button.
class _ToolbarPopupMenu extends StatefulWidget {
  final IconData iconData;
  final String variant;
  final String tooltip;
  final List<PopupMenuEntry<String>> entries;
  final ValueChanged<String> onSelected;
  final SduiTheme theme;

  const _ToolbarPopupMenu({
    super.key,
    required this.iconData,
    required this.variant,
    required this.tooltip,
    required this.entries,
    required this.onSelected,
    required this.theme,
  });

  @override
  State<_ToolbarPopupMenu> createState() => _ToolbarPopupMenuState();
}

class _ToolbarPopupMenuState extends State<_ToolbarPopupMenu> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final wt = t.window;
    final primary = t.colors.primary;
    final isPrimary = widget.variant == 'toolbar-primary';

    final Color bg;
    final Color fg;
    final Border? border;

    if (isPrimary) {
      bg = _hovered
          ? HSLColor.fromColor(primary).withLightness(
              (HSLColor.fromColor(primary).lightness - 0.08).clamp(0, 1)).toColor()
          : primary;
      fg = t.colors.onPrimary;
      border = null;
    } else {
      bg = _hovered ? primary.withAlpha(t.opacity.subtle) : Colors.transparent;
      fg = primary;
      border = Border.all(color: primary, width: wt.toolbarButtonBorderWidth);
    }

    return PopupMenuButton<String>(
      tooltip: widget.tooltip,
      itemBuilder: (_) => widget.entries,
      onSelected: widget.onSelected,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: t.animation.fast,
          width: wt.toolbarButtonSize,
          height: wt.toolbarButtonSize,
          decoration: BoxDecoration(
            color: bg,
            border: border,
            borderRadius: BorderRadius.circular(wt.toolbarButtonRadius),
          ),
          child: Center(
            child: Icon(widget.iconData, size: wt.toolbarButtonIconSize, color: fg),
          ),
        ),
      ),
    );
  }
}

/// Multi-select PopupMenu with checkboxes. Menu stays open on toggle.
/// Publishes the full selected set on each change.
class _MultiSelectPopupMenu extends StatefulWidget {
  final SduiNode node;
  final SduiRenderContext ctx;
  const _MultiSelectPopupMenu({super.key, required this.node, required this.ctx});
  @override
  State<_MultiSelectPopupMenu> createState() => _MultiSelectPopupMenuState();
}

class _MultiSelectPopupMenuState extends State<_MultiSelectPopupMenu> {
  late Set<String> _selected;
  OverlayEntry? _overlay;
  final _triggerKey = GlobalKey();

  List<Map<String, dynamic>> get _items =>
      (widget.node.props['items'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();

  @override
  void initState() {
    super.initState();
    // Initialize selected from items with selected:true
    _selected = _items
        .where((m) => PropConverter.to<bool>(m['selected']) == true)
        .map((m) => PropConverter.to<String>(m['value']) ?? '')
        .where((v) => v.isNotEmpty)
        .toSet();
  }

  void _publish() {
    final channel = PropConverter.to<String>(widget.node.props['channel']) ?? '';
    debugPrint('[MultiSelect] publish: channel=$channel selected=$_selected (${_selected.length} items)');
    if (channel.isNotEmpty) {
      widget.ctx.eventBus.publish(
        channel,
        EventPayload(
          type: 'menu.multiSelect',
          sourceWidgetId: widget.node.id,
          data: {'selected': _selected.toList()},
        ),
      );
    }
  }

  void _toggle(String value) {
    setState(() {
      if (_selected.contains(value)) {
        _selected.remove(value);
      } else {
        _selected.add(value);
      }
    });
    _publish();
    _showOverlay(); // rebuild overlay
  }

  void _toggleAll() {
    setState(() {
      final allValues = _items
          .where((m) => PropConverter.to<bool>(m['divider']) != true)
          .map((m) => PropConverter.to<String>(m['value']) ?? '')
          .where((v) => v.isNotEmpty)
          .toSet();
      if (_selected.length == allValues.length) {
        _selected.clear();
      } else {
        _selected = Set.from(allValues);
      }
    });
    _publish();
    _showOverlay(); // rebuild overlay
  }

  void _dismiss() {
    _overlay?.remove();
    _overlay = null;
  }

  void _showOverlay() {
    _overlay?.remove();

    final renderBox = _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final t = widget.ctx.theme;
    final items = _items;
    final allNonDivider = items
        .where((m) => PropConverter.to<bool>(m['divider']) != true)
        .map((m) => PropConverter.to<String>(m['value']) ?? '')
        .where((v) => v.isNotEmpty)
        .toSet();
    final allSelected = _selected.length == allNonDivider.length;
    final someSelected = _selected.isNotEmpty && !allSelected;

    _overlay = OverlayEntry(builder: (context) {
      return Stack(children: [
        // Dismiss backdrop
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _dismiss,
            child: const SizedBox.expand(),
          ),
        ),
        // Dropdown
        Positioned(
          left: offset.dx,
          top: offset.dy + size.height + t.spacing.xs,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(t.radius.md),
            color: t.colors.surface,
            child: Container(
              width: 220,
              constraints: const BoxConstraints(maxHeight: 380),
              decoration: BoxDecoration(
                border: Border.all(color: t.colors.outlineVariant, width: t.lineWeight.subtle),
                borderRadius: BorderRadius.circular(t.radius.md),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Select All / Reset header
                  InkWell(
                    onTap: _toggleAll,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: t.spacing.sm, vertical: t.spacing.xs),
                      child: Row(children: [
                        SizedBox(
                          width: 20, height: 20,
                          child: Checkbox(
                            value: allSelected ? true : (someSelected ? null : false),
                            tristate: true,
                            onChanged: (_) => _toggleAll(),
                            activeColor: t.colors.primary,
                          ),
                        ),
                        SizedBox(width: t.spacing.sm),
                        Text(
                          allSelected ? 'Deselect All' : 'Select All',
                          style: t.textStyles.labelSmall.toTextStyle(
                            color: t.colors.primary,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ]),
                    ),
                  ),
                  Divider(height: 1, color: t.colors.outlineVariant),
                  // Scrollable items
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(vertical: t.spacing.xs),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: items.map((m) {
                          if (PropConverter.to<bool>(m['divider']) == true) {
                            return Divider(height: 1, color: t.colors.outlineVariant);
                          }
                          final value = PropConverter.to<String>(m['value']) ?? '';
                          final label = PropConverter.to<String>(m['label']) ?? value;
                          final checked = _selected.contains(value);
                          return InkWell(
                            onTap: () => _toggle(value),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: t.spacing.sm, vertical: t.spacing.xs / 2),
                              child: Row(children: [
                                SizedBox(
                                  width: 20, height: 20,
                                  child: Checkbox(
                                    value: checked,
                                    onChanged: (_) => _toggle(value),
                                    activeColor: t.colors.primary,
                                  ),
                                ),
                                SizedBox(width: t.spacing.sm),
                                Expanded(
                                  child: Text(label,
                                    style: t.textStyles.bodySmall.toTextStyle(
                                      color: t.colors.onSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ]),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ]);
    });

    Overlay.of(context).insert(_overlay!);
  }

  @override
  void dispose() {
    _dismiss();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.ctx.theme;
    final node = widget.node;
    final variant = PropConverter.to<String>(node.props['variant']);
    final iconName = PropConverter.to<String>(node.props['icon']) ?? 'grid_on';
    final tooltip = PropConverter.to<String>(node.props['tooltip']) ?? '';
    final iconData = _iconMap[iconName] ?? FontAwesomeIcons.tableColumns;

    // Toolbar variant trigger
    if (variant == 'toolbar-primary' || variant == 'toolbar-secondary') {
      return _ToolbarIconButton(
        key: _triggerKey,
        icon: iconData,
        iconSize: t.window.toolbarButtonIconSize,
        isPrimary: variant == 'toolbar-primary',
        enabled: true,
        tooltip: tooltip,
        onTap: _showOverlay,
        theme: t,
      );
    }

    // Default trigger
    final iconSize = PropConverter.to<double>(node.props['iconSize']) ?? t.iconSize.md;
    final iconColor = _resolveColor(node.props['iconColor'], t) ?? t.colors.onSurface;
    Widget trigger = IconButton(
      key: _triggerKey,
      icon: Icon(iconData, size: iconSize, color: iconColor),
      tooltip: tooltip,
      onPressed: _showOverlay,
    );
    return trigger;
  }
}

Widget _buildSwitch(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  return _SduiSwitch(node: node, context: ctx);
}

Widget _buildCheckbox(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  return _SduiCheckbox(node: node, context: ctx);
}

Widget _buildDivider(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  return Divider(
    height: PropConverter.to<double>(node.props['height']) ?? ctx.theme.lineWeight.subtle,
    thickness: PropConverter.to<double>(node.props['thickness']) ?? ctx.theme.lineWeight.subtle,
    color: _resolveColor(node.props['color'], ctx.theme),
    indent: PropConverter.to<double>(node.props['indent']) ?? 0,
    endIndent: PropConverter.to<double>(node.props['endIndent']) ?? 0,
  );
}

Widget _buildChip(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  final label = PropConverter.to<String>(node.props['label']) ?? '';
  final color = _resolveColor(node.props['color'], ctx.theme);
  final avatarIcon = PropConverter.to<String>(node.props['avatar']);

  return Chip(
    label: Text(label),
    backgroundColor: color?.withAlpha(ctx.theme.opacity.subtle),
    avatar: avatarIcon != null
        ? Icon(_iconMap[avatarIcon] ?? FontAwesomeIcons.circleQuestion, size: ctx.theme.iconSize.sm)
        : null,
  );
}

Widget _buildCircleAvatar(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  final text = PropConverter.to<String>(node.props['text']);
  final iconName = PropConverter.to<String>(node.props['icon']);
  final radius = PropConverter.to<double>(node.props['radius']) ?? 20;
  final color = _resolveColor(node.props['color'], ctx.theme) ??
      ctx.theme.colors.primary;

  return CircleAvatar(
    radius: radius,
    backgroundColor: color,
    child: text != null
        ? Text(text.isNotEmpty ? text[0].toUpperCase() : '',
            style: TextStyle(color: ctx.theme.colors.onPrimary))
        : iconName != null
            ? Icon(_iconMap[iconName] ?? FontAwesomeIcons.user,
                color: ctx.theme.colors.onPrimary, size: radius)
            : null,
  );
}

Widget _buildDropdownButton(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  return _SduiDropdown(node: node, context: ctx);
}

// -- Stateful interactive widgets --

class _SduiTextField extends StatefulWidget {
  final SduiNode node;
  final SduiRenderContext context;

  const _SduiTextField({required this.node, required this.context});

  @override
  State<_SduiTextField> createState() => _SduiTextFieldState();
}

class _SduiTextFieldState extends State<_SduiTextField> {
  late final TextEditingController _controller;
  StreamSubscription? _clearSub;

  @override
  void initState() {
    super.initState();
    final initial = PropConverter.to<String>(widget.node.props['value']) ?? '';
    _controller = TextEditingController(text: initial);
    _subscribeClear();
  }

  void _subscribeClear() {
    final channel = PropConverter.to<String>(widget.node.props['clearOn']);
    if (channel == null || channel.isEmpty) return;
    _clearSub = widget.context.eventBus.subscribe(channel).listen((_) {
      if (!mounted) return;
      _controller.clear();
      _onChanged('');
    });
  }

  @override
  void dispose() {
    _clearSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    widget.context.eventBus.publish(
      'input.${widget.node.id}.changed',
      EventPayload(
        type: 'input.changed',
        sourceWidgetId: widget.node.id,
        data: {'value': value},
      ),
    );
  }

  void _onSubmitted(String value) {
    widget.context.eventBus.publish(
      'input.${widget.node.id}.submitted',
      EventPayload(
        type: 'input.submitted',
        sourceWidgetId: widget.node.id,
        data: {'value': value},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.context.theme;
    final hint = PropConverter.to<String>(widget.node.props['hint']);
    // maxLines: null means unlimited (grow with content). 0 also treated as null.
    final rawMaxLines = widget.node.props['maxLines'];
    final maxLines = (rawMaxLines == null || rawMaxLines == 'null' || rawMaxLines == 0)
        ? null
        : PropConverter.to<int>(rawMaxLines) ?? 1;
    final obscure = PropConverter.to<bool>(widget.node.props['obscureText']) ?? false;
    final enabled = PropConverter.to<bool>(widget.node.props['enabled']) ?? true;
    final autofocus = PropConverter.to<bool>(widget.node.props['autofocus']) ?? false;
    final borderless = PropConverter.to<bool>(widget.node.props['borderless']) ?? false;
    final color = _resolveColor(widget.node.props['color'], theme);

    final label = PropConverter.to<String>(widget.node.props['label']);

    final submitOnEnter = PropConverter.to<bool>(widget.node.props['submitOnEnter']) ?? false;
    final fontFamily = PropConverter.to<String>(widget.node.props['fontFamily']);
    final prefixIconName = PropConverter.to<String>(widget.node.props['prefixIcon']);
    final size = PropConverter.to<String>(widget.node.props['size']);
    final isMultiline = !obscure && (maxLines == null || maxLines > 1);

    Widget textField = TextField(
      controller: _controller,
      onChanged: _onChanged,
      onSubmitted: _onSubmitted,
      maxLines: obscure ? 1 : maxLines,
      minLines: isMultiline ? 1 : null,
      obscureText: obscure,
      enabled: enabled,
      autofocus: autofocus,
      style: TextStyle(
        color: color ?? theme.colors.onSurface,
        fontSize: theme.textStyles.bodyMedium.fontSize,
        fontFamily: fontFamily,
      ),
      decoration: borderless
          ? InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: theme.colors.onSurfaceMuted),
              prefixIcon: prefixIconName != null
                  ? Icon(_resolveIcon(prefixIconName, 'solid'), size: theme.iconSize.sm, color: theme.colors.onSurfaceMuted)
                  : null,
              prefixIconConstraints: prefixIconName != null
                  ? BoxConstraints(minWidth: theme.spacing.lg, minHeight: 0)
                  : null,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
              isDense: true,
            )
          : InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: theme.colors.onSurfaceMuted),
              prefixIcon: prefixIconName != null
                  ? Icon(_resolveIcon(prefixIconName, 'solid'), size: theme.iconSize.sm, color: theme.colors.onSurfaceMuted)
                  : null,
              prefixIconConstraints: prefixIconName != null
                  ? BoxConstraints(minWidth: theme.spacing.lg, minHeight: 0)
                  : null,
              isDense: true,
            ),
    );

    // Apply size constraint for single-line bordered fields.
    if (!isMultiline && !borderless && size != null) {
      final h = size == 'sm' ? theme.controlHeight.sm : theme.controlHeight.md;
      textField = SizedBox(height: h, child: textField);
    }

    // Textarea: minimum 80px height per style guide.
    if (isMultiline) {
      textField = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 80),
        child: textField,
      );
    }

    // Enter to submit for multiline fields (Shift+Enter for newline).
    if (submitOnEnter && isMultiline) {
      textField = Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.enter &&
              !HardwareKeyboard.instance.isShiftPressed) {
            final text = _controller.text.trim();
            if (text.isNotEmpty) {
              _onSubmitted(text);
              _controller.clear();
              _onChanged('');
            }
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: textField,
      );
    }

    if (label != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(
            fontSize: theme.textStyles.labelSmall.fontSize,
            fontWeight: FontWeight.w500,
            color: theme.colors.onSurfaceVariant,
          )),
          SizedBox(height: theme.spacing.xs),
          textField,
        ],
      );
    }
    return textField;
  }
}

// ---------------------------------------------------------------------------
// ToggleButton — Off=Secondary, On=Primary
// ---------------------------------------------------------------------------

Widget _buildToggleButton(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  return _SduiToggleButton(
    key: ValueKey('toggle-${node.id}'),
    node: node,
    context: ctx,
  );
}

class _SduiToggleButton extends StatefulWidget {
  final SduiNode node;
  final SduiRenderContext context;

  const _SduiToggleButton({super.key, required this.node, required this.context});

  @override
  State<_SduiToggleButton> createState() => _SduiToggleButtonState();
}

class _SduiToggleButtonState extends State<_SduiToggleButton> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = PropConverter.to<bool>(widget.node.props['value']) ?? false;
  }

  void _onTap() {
    setState(() => _value = !_value);
    widget.context.eventBus.publish(
      'input.${widget.node.id}.changed',
      EventPayload(
        type: 'input.changed',
        sourceWidgetId: widget.node.id,
        data: {'value': _value},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = PropConverter.to<bool>(widget.node.props['enabled']) ?? true;
    final iconName = PropConverter.to<String>(widget.node.props['icon']);
    final text = PropConverter.to<String>(widget.node.props['text']);
    final tooltip = PropConverter.to<String>(widget.node.props['tooltip']);
    final btn = widget.context.theme.button;
    final colors = widget.context.theme.colors;

    final iconData = iconName != null
        ? (_iconMap[iconName] ?? FontAwesomeIcons.circleQuestion)
        : null;
    final iconSize = widget.context.theme.iconSize.sm;

    // On = Primary style, Off = Secondary style
    final ButtonStyle style;
    if (_value) {
      style = ElevatedButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        padding: EdgeInsets.symmetric(horizontal: btn.paddingH, vertical: btn.paddingV),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(btn.borderRadius)),
      );
    } else {
      style = OutlinedButton.styleFrom(
        foregroundColor: colors.primary,
        side: BorderSide(color: colors.primary, width: btn.outlinedBorderWidth),
        padding: EdgeInsets.symmetric(horizontal: btn.paddingH, vertical: btn.paddingV),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(btn.borderRadius)),
      );
    }

    Widget button;
    final onPressed = enabled ? _onTap : null;

    // Icon only
    if (iconData != null && (text == null || text.isEmpty)) {
      button = SizedBox(
        width: widget.context.theme.controlHeight.md,
        height: widget.context.theme.controlHeight.md,
        child: _value
            ? ElevatedButton(
                onPressed: onPressed,
                style: style.copyWith(padding: WidgetStateProperty.all(EdgeInsets.zero)),
                child: Icon(iconData, size: iconSize),
              )
            : OutlinedButton(
                onPressed: onPressed,
                style: style.copyWith(padding: WidgetStateProperty.all(EdgeInsets.zero)),
                child: Icon(iconData, size: iconSize),
              ),
      );
    }
    // Icon + text
    else if (iconData != null && text != null && text.isNotEmpty) {
      button = _value
          ? ElevatedButton.icon(
              onPressed: onPressed,
              style: style,
              icon: Icon(iconData, size: iconSize),
              label: Text(text),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              style: style,
              icon: Icon(iconData, size: iconSize),
              label: Text(text),
            );
    }
    // Text only
    else {
      button = _value
          ? ElevatedButton(onPressed: onPressed, style: style, child: Text(text ?? ''))
          : OutlinedButton(onPressed: onPressed, style: style, child: Text(text ?? ''));
    }

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: button);
    }
    return button;
  }
}

class _SduiSwitch extends StatefulWidget {
  final SduiNode node;
  final SduiRenderContext context;

  const _SduiSwitch({required this.node, required this.context});

  @override
  State<_SduiSwitch> createState() => _SduiSwitchState();
}

class _SduiSwitchState extends State<_SduiSwitch> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = PropConverter.to<bool>(widget.node.props['value']) ?? false;
  }

  void _onChanged(bool value) {
    setState(() => _value = value);
    widget.context.eventBus.publish(
      'input.${widget.node.id}.changed',
      EventPayload(
        type: 'input.changed',
        sourceWidgetId: widget.node.id,
        data: {'value': value},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = PropConverter.to<bool>(widget.node.props['enabled']) ?? true;
    final color = _resolveColor(widget.node.props['color'], widget.context.theme);

    // Approved size: matches default button height (tercen-style/testboard-controls)
    return SizedBox(
      width: 65,
      height: widget.context.theme.controlHeight.md,
      child: FittedBox(
        fit: BoxFit.contain,
        child: Switch(
      value: _value,
      onChanged: enabled ? _onChanged : null,
      activeTrackColor: color ?? widget.context.theme.colors.primary,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
      ),
    );
  }
}

class _SduiCheckbox extends StatefulWidget {
  final SduiNode node;
  final SduiRenderContext context;

  const _SduiCheckbox({required this.node, required this.context});

  @override
  State<_SduiCheckbox> createState() => _SduiCheckboxState();
}

class _SduiCheckboxState extends State<_SduiCheckbox> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = PropConverter.to<bool>(widget.node.props['value']) ?? false;
  }

  void _onChanged(bool? value) {
    final v = value ?? false;
    setState(() => _value = v);
    widget.context.eventBus.publish(
      'input.${widget.node.id}.changed',
      EventPayload(
        type: 'input.changed',
        sourceWidgetId: widget.node.id,
        data: {'value': v},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = PropConverter.to<bool>(widget.node.props['enabled']) ?? true;
    final label = PropConverter.to<String>(widget.node.props['label']);
    final color = _resolveColor(widget.node.props['color'], widget.context.theme);

    final checkbox = Checkbox(
      value: _value,
      onChanged: enabled ? _onChanged : null,
      activeColor: color ?? widget.context.theme.colors.primary,
    );

    if (label != null) {
      return InkWell(
        onTap: enabled ? () => _onChanged(!_value) : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            checkbox,
            Text(label, style: TextStyle(
              color: widget.context.theme.colors.onSurface,
              fontSize: widget.context.theme.textStyles.bodyMedium.fontSize,
            )),
          ],
        ),
      );
    }
    return checkbox;
  }
}

class _SduiDropdown extends StatefulWidget {
  final SduiNode node;
  final SduiRenderContext context;

  const _SduiDropdown({required this.node, required this.context});

  @override
  State<_SduiDropdown> createState() => _SduiDropdownState();
}

class _SduiDropdownState extends State<_SduiDropdown> {
  String? _value;

  @override
  void initState() {
    super.initState();
    _value = PropConverter.to<String>(widget.node.props['value']);
  }

  void _onChanged(String? value) {
    if (value == null) return;
    setState(() => _value = value);
    widget.context.eventBus.publish(
      'input.${widget.node.id}.changed',
      EventPayload(
        type: 'input.changed',
        sourceWidgetId: widget.node.id,
        data: {'value': value},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = PropConverter.to<bool>(widget.node.props['enabled']) ?? true;
    final hint = PropConverter.to<String>(widget.node.props['hint']);
    final rawItems = widget.node.props['items'];

    final items = <DropdownMenuItem<String>>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is String) {
          items.add(DropdownMenuItem(value: item, child: Text(item)));
        } else if (item is Map<String, dynamic>) {
          final value = PropConverter.to<String>(item['value']) ?? '';
          final label = PropConverter.to<String>(item['label']) ?? value;
          items.add(DropdownMenuItem(value: value, child: Text(label)));
        }
      }
    }

    final label = PropConverter.to<String>(widget.node.props['label']);
    final theme = widget.context.theme;

    // Use DropdownButtonFormField — inherits border, focus ring, height,
    // padding from inputDecorationTheme (same as TextField).
    final dropdown = DropdownButtonFormField<String>(
      value: _value,
      items: items,
      onChanged: enabled ? _onChanged : null,
      decoration: InputDecoration(
        hintText: hint,
      ),
      style: TextStyle(
        color: theme.colors.onSurface,
        fontSize: theme.textStyles.bodyMedium.fontSize,
      ),
      isExpanded: true,
    );

    if (label != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(
            fontSize: theme.textStyles.labelSmall.fontSize,
            fontWeight: FontWeight.w500,
            color: theme.colors.onSurfaceVariant,
          )),
          SizedBox(height: theme.spacing.xs),
          dropdown,
        ],
      );
    }
    return dropdown;
  }
}

// -- Helpers --

MainAxisAlignment _parseMainAxis(dynamic value) => switch (value) {
      'start' => MainAxisAlignment.start,
      'end' => MainAxisAlignment.end,
      'center' => MainAxisAlignment.center,
      'spaceBetween' => MainAxisAlignment.spaceBetween,
      'spaceAround' => MainAxisAlignment.spaceAround,
      'spaceEvenly' => MainAxisAlignment.spaceEvenly,
      _ => MainAxisAlignment.start,
    };

CrossAxisAlignment _parseCrossAxis(dynamic value) => switch (value) {
      'start' => CrossAxisAlignment.start,
      'end' => CrossAxisAlignment.end,
      'center' => CrossAxisAlignment.center,
      'stretch' => CrossAxisAlignment.stretch,
      _ => CrossAxisAlignment.center,
    };

MainAxisSize _parseMainAxisSize(dynamic value) => switch (value) {
      'min' => MainAxisSize.min,
      'max' => MainAxisSize.max,
      _ => MainAxisSize.max,
    };

/// Resolves a color value: hex string (#RRGGBB/#AARRGGBB), named Material color,
/// or semantic theme token name (e.g., "primary", "surface", "error").
Color? _resolveColor(dynamic value, SduiTheme theme) {
  if (value == null) return null;
  if (value is String) {
    // Hex color (#RRGGBB or #AARRGGBB)
    if (value.startsWith('#')) {
      final h = value.substring(1);
      if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
      if (h.length == 8) return Color(int.parse(h, radix: 16));
    }
    // Named Material colors (kept for backward compat)
    final named = switch (value) {
      'red' => Colors.red,
      'blue' => Colors.blue,
      'green' => Colors.green,
      'orange' => Colors.orange,
      'purple' => Colors.purple,
      'white' => Colors.white,
      'black' => Colors.black,
      'grey' || 'gray' => Colors.grey,
      _ => null,
    };
    if (named != null) return named;
    // Semantic theme tokens — delegates to colors.resolve()
    return theme.colors.resolve(value);
  }
  return null;
}

FontWeight? _parseFontWeight(dynamic value) => switch (value) {
      'bold' => FontWeight.bold,
      'w100' => FontWeight.w100,
      'w200' => FontWeight.w200,
      'w300' => FontWeight.w300,
      'w400' => FontWeight.w400,
      'w500' => FontWeight.w500,
      'w600' => FontWeight.w600,
      'w700' => FontWeight.w700,
      'w800' => FontWeight.w800,
      'w900' => FontWeight.w900,
      _ => null,
    };

EdgeInsets? _edgeInsets(dynamic value, {SduiSpacingTokens? spacing}) {
  if (value == null) return null;
  // Accept spacing token names ("sm", "md", etc.)
  if (value is String && spacing != null) {
    final resolved = spacing.resolve(value);
    if (resolved != null) return EdgeInsets.all(resolved);
  }
  // Accept [top, right, bottom, left] or [vertical, horizontal] arrays
  if (value is List) {
    final doubles = value.map((e) => PropConverter.to<double>(e) ?? 0.0).toList();
    if (doubles.length == 4) {
      return EdgeInsets.fromLTRB(doubles[3], doubles[0], doubles[1], doubles[2]);
    }
    if (doubles.length == 2) {
      return EdgeInsets.symmetric(vertical: doubles[0], horizontal: doubles[1]);
    }
    if (doubles.length == 1) {
      return EdgeInsets.all(doubles[0]);
    }
  }
  final v = PropConverter.to<double>(value);
  if (v == null) return null;
  return EdgeInsets.all(v);
}

/// Resolve a spacing value — either a token name or a numeric value.
double? _resolveSpacing(dynamic value, SduiSpacingTokens spacing) {
  if (value == null) return null;
  if (value is String) return spacing.resolve(value);
  return PropConverter.to<double>(value);
}

// -- Icon widget --

Widget _buildIcon(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  final name = PropConverter.to<String>(node.props['icon']) ?? '';
  final size = PropConverter.to<double>(node.props['size']) ?? ctx.theme.iconSize.md;
  final weight = PropConverter.to<String>(node.props['weight']) ?? 'solid';
  // When no explicit color, leave null so IconTheme can cascade
  // (e.g., link color from a parent Action with openUrl intent).
  final color = _resolveColor(node.props['color'], ctx.theme);

  final iconData = _resolveIcon(name, weight);
  if (iconData == null) {
    ErrorReporter.instance.report(
      'Unknown icon name: "$name"',
      source: 'sdui.Icon',
      context: 'id: ${node.id}',
      severity: ErrorSeverity.warning,
    );
    return Icon(FontAwesomeIcons.circleQuestion, size: size, color: color);
  }
  return Icon(iconData, size: size, color: color);
}

/// Icon map — all entries use SOLID weight by default.
/// FA6 Free has 1407 solid icons but only 169 regular icons.
/// Solid is guaranteed to have a glyph; regular may not.
/// Use weight: "regular" in catalog.json to get line-style icons for
/// the 169 icons that have both weights.
const Map<String, IconData> _iconMap = {
  // Navigation
  'home': FontAwesomeIcons.solidHouse,
  'menu': FontAwesomeIcons.bars,
  'arrow_back': FontAwesomeIcons.arrowLeft,
  'arrow_forward': FontAwesomeIcons.arrowRight,
  'chevron_left': FontAwesomeIcons.chevronLeft,
  'chevron_right': FontAwesomeIcons.chevronRight,
  'expand_more': FontAwesomeIcons.chevronDown,
  'expand_less': FontAwesomeIcons.chevronUp,
  'close': FontAwesomeIcons.xmark,
  'expand': FontAwesomeIcons.expand,
  'fullscreen': FontAwesomeIcons.expand,
  'fullscreen_exit': FontAwesomeIcons.compress,
  'compress': FontAwesomeIcons.compress,

  // Actions
  'add': FontAwesomeIcons.plus,
  'remove': FontAwesomeIcons.minus,
  'delete': FontAwesomeIcons.trash,
  'edit': FontAwesomeIcons.pen,
  'search': FontAwesomeIcons.magnifyingGlass,
  'refresh': FontAwesomeIcons.arrowsRotate,
  'check': FontAwesomeIcons.check,
  'clear': FontAwesomeIcons.xmark,
  'save': FontAwesomeIcons.solidFloppyDisk,
  'send': FontAwesomeIcons.solidPaperPlane,
  'download': FontAwesomeIcons.download,
  'upload': FontAwesomeIcons.upload,
  'share': FontAwesomeIcons.shareNodes,
  'copy': FontAwesomeIcons.solidCopy,
  'content_copy': FontAwesomeIcons.solidCopy,
  'paste': FontAwesomeIcons.solidPaste,
  'content_paste': FontAwesomeIcons.solidPaste,
  'undo': FontAwesomeIcons.rotateLeft,
  'redo': FontAwesomeIcons.rotateRight,
  'sort': FontAwesomeIcons.arrowDownWideShort,
  'sort_asc': FontAwesomeIcons.arrowUpWideShort,
  'filter': FontAwesomeIcons.filter,
  'filter_list': FontAwesomeIcons.filter,

  // Files & folders
  'folder': FontAwesomeIcons.solidFolder,
  'folder_open': FontAwesomeIcons.solidFolderOpen,
  'file': FontAwesomeIcons.solidFile,
  'description': FontAwesomeIcons.solidFileLines,
  'attachment': FontAwesomeIcons.paperclip,
  'link': FontAwesomeIcons.link,
  'cloud': FontAwesomeIcons.solidCloud,
  'cloud_upload': FontAwesomeIcons.cloudArrowUp,
  'cloud_download': FontAwesomeIcons.cloudArrowDown,
  'storage': FontAwesomeIcons.database,

  // Status & feedback
  'info': FontAwesomeIcons.circleInfo,
  'info_outline': FontAwesomeIcons.circleInfo,
  'warning': FontAwesomeIcons.triangleExclamation,
  'warning_amber': FontAwesomeIcons.triangleExclamation,
  'error': FontAwesomeIcons.circleExclamation,
  'error_outline': FontAwesomeIcons.circleExclamation,
  'check_circle': FontAwesomeIcons.solidCircleCheck,
  'cancel': FontAwesomeIcons.ban,
  'help': FontAwesomeIcons.solidCircleQuestion,
  'help_outline': FontAwesomeIcons.solidCircleQuestion,

  // People & identity
  'person': FontAwesomeIcons.solidUser,
  'people': FontAwesomeIcons.users,
  'group': FontAwesomeIcons.userGroup,
  'account_circle': FontAwesomeIcons.solidCircleUser,

  // Communication
  'email': FontAwesomeIcons.solidEnvelope,
  'chat': FontAwesomeIcons.solidComment,
  'comments': FontAwesomeIcons.solidComments,
  'message': FontAwesomeIcons.solidMessage,
  'notifications': FontAwesomeIcons.solidBell,

  // Content & media
  'image': FontAwesomeIcons.solidImage,
  'photo': FontAwesomeIcons.solidImage,
  'camera': FontAwesomeIcons.solidCamera,
  'video': FontAwesomeIcons.video,
  'music': FontAwesomeIcons.music,

  // Data & charts
  'table': FontAwesomeIcons.table,
  'table_chart': FontAwesomeIcons.table,
  'grid_on': FontAwesomeIcons.tableColumns,
  'bar_chart': FontAwesomeIcons.solidChartBar,
  'chart': FontAwesomeIcons.solidChartBar,
  'pie_chart': FontAwesomeIcons.chartPie,
  'scatter_plot': FontAwesomeIcons.chartLine,
  'analytics': FontAwesomeIcons.chartLine,
  'trending_up': FontAwesomeIcons.arrowTrendUp,
  'trending_down': FontAwesomeIcons.arrowTrendDown,

  // Science & lab
  'science': FontAwesomeIcons.flask,
  'biotech': FontAwesomeIcons.dna,

  // Toggles & controls
  'visibility': FontAwesomeIcons.solidEye,
  'visibility_off': FontAwesomeIcons.solidEyeSlash,
  'lock': FontAwesomeIcons.lock,
  'lock_open': FontAwesomeIcons.lockOpen,
  'settings': FontAwesomeIcons.gear,
  'tune': FontAwesomeIcons.sliders,
  'toggle_on': FontAwesomeIcons.toggleOn,
  'toggle_off': FontAwesomeIcons.toggleOff,

  // Time
  'calendar': FontAwesomeIcons.solidCalendar,
  'calendar_today': FontAwesomeIcons.calendarDay,
  'clock': FontAwesomeIcons.solidClock,
  'clock_rotate_left': FontAwesomeIcons.clockRotateLeft,
  'history': FontAwesomeIcons.clockRotateLeft,
  'access_time': FontAwesomeIcons.solidClock,
  'schedule': FontAwesomeIcons.solidCalendarCheck,

  // Workflow & structure
  'account_tree': FontAwesomeIcons.sitemap,
  'workflow': FontAwesomeIcons.sitemap,
  'hub': FontAwesomeIcons.circleNodes,
  'category': FontAwesomeIcons.shapes,
  'layers': FontAwesomeIcons.layerGroup,
  'view_list': FontAwesomeIcons.list,
  'view_module': FontAwesomeIcons.grip,
  'dashboard': FontAwesomeIcons.gaugeHigh,
  'widgets': FontAwesomeIcons.puzzlePiece,
  'call_merge': FontAwesomeIcons.codeMerge,
  'merge': FontAwesomeIcons.codeMerge,
  'call_split': FontAwesomeIcons.codeBranch,
  'input': FontAwesomeIcons.rightToBracket,
  'output': FontAwesomeIcons.rightFromBracket,
  'login': FontAwesomeIcons.rightToBracket,
  'logout': FontAwesomeIcons.rightFromBracket,
  'smart_toy': FontAwesomeIcons.robot,
  'checklist': FontAwesomeIcons.listCheck,
  'shuffle': FontAwesomeIcons.shuffle,
  'insert_drive_file': FontAwesomeIcons.solidFile,
  'auto_fix_high': FontAwesomeIcons.wandMagicSparkles,

  // Media controls
  'play': FontAwesomeIcons.play,
  'play_arrow': FontAwesomeIcons.play,
  'pause': FontAwesomeIcons.pause,
  'stop': FontAwesomeIcons.stop,
  'skip_next': FontAwesomeIcons.forwardStep,
  'skip_previous': FontAwesomeIcons.backwardStep,

  // Misc
  'star': FontAwesomeIcons.solidStar,
  'star_border': FontAwesomeIcons.solidStar,
  'favorite': FontAwesomeIcons.solidHeart,
  'favorite_border': FontAwesomeIcons.solidHeart,
  'bookmark': FontAwesomeIcons.solidBookmark,
  'bookmark_border': FontAwesomeIcons.solidBookmark,
  'label': FontAwesomeIcons.tag,
  'tag': FontAwesomeIcons.tag,
  'pin': FontAwesomeIcons.thumbtack,
  'location_on': FontAwesomeIcons.locationDot,
  'location': FontAwesomeIcons.locationDot,
  'location_pin': FontAwesomeIcons.locationPin,
  'push_pin': FontAwesomeIcons.thumbtack,
  'code': FontAwesomeIcons.code,
  'terminal': FontAwesomeIcons.terminal,
  'bug_report': FontAwesomeIcons.bug,
  'build': FontAwesomeIcons.screwdriverWrench,
  'extension': FontAwesomeIcons.puzzlePiece,
  'power': FontAwesomeIcons.powerOff,
  'drag_handle': FontAwesomeIcons.gripLines,
  'more_vert': FontAwesomeIcons.ellipsisVertical,
  'more_horiz': FontAwesomeIcons.ellipsis,
  'open_in_new': FontAwesomeIcons.arrowUpRightFromSquare,
  'launch': FontAwesomeIcons.arrowUpRightFromSquare,
  'print': FontAwesomeIcons.print,
  'inventory': FontAwesomeIcons.boxesStacked,
  'library_add': FontAwesomeIcons.bookMedical,

  // Theme toggle icons
  'light_mode': FontAwesomeIcons.solidSun,
  'dark_mode': FontAwesomeIcons.solidMoon,
  'brightness_high': FontAwesomeIcons.solidSun,
  'brightness_low': FontAwesomeIcons.solidMoon,

  // Additional FA6 keys
  'xmark': FontAwesomeIcons.xmark,
  'plus': FontAwesomeIcons.plus,
  'minus': FontAwesomeIcons.minus,
  'magnifying_glass': FontAwesomeIcons.magnifyingGlass,
  'magnifying-glass-plus': FontAwesomeIcons.magnifyingGlassPlus,
  'magnifying-glass-minus': FontAwesomeIcons.magnifyingGlassMinus,
  'floppy_disk': FontAwesomeIcons.solidFloppyDisk,
  'arrows_rotate': FontAwesomeIcons.arrowsRotate,
  'file_export': FontAwesomeIcons.fileExport,
  'box_open': FontAwesomeIcons.boxOpen,
  'sun': FontAwesomeIcons.solidSun,
  'moon': FontAwesomeIcons.solidMoon,
  'brain': FontAwesomeIcons.brain,
  'list_check': FontAwesomeIcons.listCheck,
  'user_gear': FontAwesomeIcons.userGear,
  'user_group': FontAwesomeIcons.userGroup,
  'right_from_bracket': FontAwesomeIcons.rightFromBracket,
  'gear': FontAwesomeIcons.gear,
  'pen': FontAwesomeIcons.pen,
  'robot': FontAwesomeIcons.robot,
  'circle': FontAwesomeIcons.solidCircle,
  'sitemap': FontAwesomeIcons.sitemap,

  // Chat-related aliases (FA6 canonical names)
  'wrench': FontAwesomeIcons.wrench,
  'circle-exclamation': FontAwesomeIcons.circleExclamation,
  'triangle-exclamation': FontAwesomeIcons.triangleExclamation,
  'paper-plane-top': FontAwesomeIcons.solidPaperPlane,

  // Workflow step icons (FA6 canonical names from spec Section 5)
  'cubes': FontAwesomeIcons.cubes,
  'eye': FontAwesomeIcons.solidEye,
  'code-merge': FontAwesomeIcons.codeMerge,
  'codeMerge': FontAwesomeIcons.codeMerge,
  'right-to-bracket': FontAwesomeIcons.rightToBracket,
  'rightToBracket': FontAwesomeIcons.rightToBracket,
  'right-from-bracket': FontAwesomeIcons.rightFromBracket,
  'rightFromBracket': FontAwesomeIcons.rightFromBracket,
  'wand-magic-sparkles': FontAwesomeIcons.wandMagicSparkles,
  'wandMagicSparkles': FontAwesomeIcons.wandMagicSparkles,
};

/// Regular-weight overrides for icons that have both regular and solid variants.
/// _iconMap defaults to solid (guaranteed glyph in FA6 Free).
/// When weight: "regular" is requested, we look up here first for the line-style variant.
const Map<String, IconData> _regularIconMap = {
  // Files & folders
  'file': FontAwesomeIcons.file,
  'folder': FontAwesomeIcons.folder,
  'folder_open': FontAwesomeIcons.folderOpen,
  'description': FontAwesomeIcons.fileLines,
  'insert_drive_file': FontAwesomeIcons.file,

  // People
  'person': FontAwesomeIcons.user,
  'user': FontAwesomeIcons.user,
  'account_circle': FontAwesomeIcons.circleUser,

  // Status
  'star': FontAwesomeIcons.star,
  'star_border': FontAwesomeIcons.star,
  'heart': FontAwesomeIcons.heart,
  'favorite': FontAwesomeIcons.heart,
  'favorite_border': FontAwesomeIcons.heart,
  'bookmark': FontAwesomeIcons.bookmark,
  'bookmark_border': FontAwesomeIcons.bookmark,
  'bell': FontAwesomeIcons.bell,
  'notifications': FontAwesomeIcons.bell,
  'check_circle': FontAwesomeIcons.circleCheck,
  'circle': FontAwesomeIcons.circle,
  'help': FontAwesomeIcons.circleQuestion,
  'help_outline': FontAwesomeIcons.circleQuestion,

  // Communication
  'comment': FontAwesomeIcons.comment,
  'chat': FontAwesomeIcons.comment,
  'comments': FontAwesomeIcons.comments,
  'message': FontAwesomeIcons.message,
  'envelope': FontAwesomeIcons.envelope,
  'email': FontAwesomeIcons.envelope,

  // Time
  'calendar': FontAwesomeIcons.calendar,
  'clock': FontAwesomeIcons.clock,
  'access_time': FontAwesomeIcons.clock,
  'schedule': FontAwesomeIcons.calendarCheck,

  // Content & media
  'image': FontAwesomeIcons.image,
  'photo': FontAwesomeIcons.image,
  'camera': FontAwesomeIcons.camera,
  'cloud': FontAwesomeIcons.cloud,

  // Actions
  'copy': FontAwesomeIcons.copy,
  'content_copy': FontAwesomeIcons.copy,
  'paste': FontAwesomeIcons.paste,
  'content_paste': FontAwesomeIcons.paste,
  'save': FontAwesomeIcons.floppyDisk,
  'floppy_disk': FontAwesomeIcons.floppyDisk,
  'send': FontAwesomeIcons.paperPlane,
  'paper-plane-top': FontAwesomeIcons.paperPlane,

  // Toggles
  'visibility': FontAwesomeIcons.eye,
  'visibility_off': FontAwesomeIcons.eyeSlash,

  // Theme
  'light_mode': FontAwesomeIcons.sun,
  'sun': FontAwesomeIcons.sun,
  'dark_mode': FontAwesomeIcons.moon,
  'moon': FontAwesomeIcons.moon,
  'brightness_high': FontAwesomeIcons.sun,
  'brightness_low': FontAwesomeIcons.moon,

  // Data
  'bar_chart': FontAwesomeIcons.chartBar,
  'chart': FontAwesomeIcons.chartBar,

  // Home
  'home': FontAwesomeIcons.house,
};

/// Resolve an icon name + weight to IconData.
/// Default (_iconMap) is solid. Regular overrides come from _regularIconMap.
IconData? _resolveIcon(String name, String weight) {
  if (weight == 'regular') {
    return _regularIconMap[name] ?? _iconMap[name];
  }
  return _iconMap[name];
}

// ---------------------------------------------------------------------------
// WorkflowActionButton
// ---------------------------------------------------------------------------

Widget _buildWorkflowActionButton(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  return _WorkflowActionButton(
    key: ValueKey('wab-${node.id}'),
    node: node,
    ctx: ctx,
  );
}

/// iconColor token → action state mapping.
/// The getWorkflowGraph service maps taskState to these colour tokens.
enum _WfActionState { run, stop, reset }

_WfActionState _iconColorToActionState(String? iconColor) => switch (iconColor) {
  'onSurfaceVariant' => _WfActionState.run,   // InitState
  'onSurfaceMuted' => _WfActionState.run,      // PendingState / CanceledState → treat as runnable
  'info' => _WfActionState.stop,               // RunningState
  'warning' => _WfActionState.stop,            // RunningDependentState
  'success' => _WfActionState.reset,           // DoneState
  'error' => _WfActionState.reset,             // FailedState
  _ => _WfActionState.run,
};

class _WorkflowActionButton extends StatefulWidget {
  final SduiNode node;
  final SduiRenderContext ctx;

  const _WorkflowActionButton({
    super.key,
    required this.node,
    required this.ctx,
  });

  @override
  State<_WorkflowActionButton> createState() => _WorkflowActionButtonState();
}

class _WorkflowActionButtonState extends State<_WorkflowActionButton> {
  StreamSubscription<EventPayload>? _selectionSub;

  // Current selection state from the graph
  String? _selectedNodeId;
  String? _selectedIconColor;
  bool _isStepSelected = false; // false = workflow root or no selection

  @override
  void initState() {
    super.initState();
    final selChannel = PropConverter.to<String>(widget.node.props['selectionChannel']) ?? '';
    debugPrint('[WfActionBtn] Subscribing to selectionChannel: "$selChannel"');
    if (selChannel.isNotEmpty) {
      _selectionSub = widget.ctx.eventBus.subscribe(selChannel).listen((event) {
        final nodeId = event.data['nodeId']?.toString();
        final iconColor = event.data['iconColor']?.toString();
        final shape = event.data['shape']?.toString();
        debugPrint('[WfActionBtn] Selection: nodeId=$nodeId iconColor=$iconColor shape=$shape');
        setState(() {
          if (nodeId == null || nodeId == _selectedNodeId) {
            _selectedNodeId = null;
            _selectedIconColor = null;
            _isStepSelected = false;
          } else {
            _selectedNodeId = nodeId;
            _selectedIconColor = iconColor;
            _isStepSelected = shape != 'circle';
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _selectionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.ctx.theme;
    final props = widget.node.props;
    final workflowId = PropConverter.to<String>(props['workflowId']) ?? '';

    // Derive action from focus + state
    final actionState = _iconColorToActionState(_selectedIconColor);

    // Button config
    late final String label;
    late final IconData icon;
    late final String channel;
    late final Map<String, dynamic> payload;

    if (_isStepSelected) {
      payload = {'stepId': _selectedNodeId ?? '', 'workflowId': workflowId};
      switch (actionState) {
        case _WfActionState.run:
          label = 'Run Step';
          icon = FontAwesomeIcons.play;
          channel = PropConverter.to<String>(props['runStepChannel']) ?? 'workflow.runStep';
        case _WfActionState.stop:
          label = 'Stop Step';
          icon = FontAwesomeIcons.stop;
          channel = PropConverter.to<String>(props['stopStepChannel']) ?? 'workflow.stopStep';
        case _WfActionState.reset:
          label = 'Reset Step';
          icon = FontAwesomeIcons.rotateLeft;
          channel = PropConverter.to<String>(props['resetStepChannel']) ?? 'workflow.resetStep';
      }
    } else {
      payload = {'workflowId': workflowId};
      switch (actionState) {
        case _WfActionState.run:
          label = 'Run All';
          icon = FontAwesomeIcons.play;
          channel = PropConverter.to<String>(props['runWorkflowChannel']) ?? 'workflow.runWorkflow';
        case _WfActionState.stop:
          label = 'Stop All';
          icon = FontAwesomeIcons.stop;
          channel = PropConverter.to<String>(props['stopWorkflowChannel']) ?? 'workflow.stopWorkflow';
        case _WfActionState.reset:
          label = 'Reset All';
          icon = FontAwesomeIcons.rotateLeft;
          channel = PropConverter.to<String>(props['resetWorkflowChannel']) ?? 'workflow.resetWorkflow';
      }
    }

    final btnSize = theme.window.toolbarButtonSize;
    return SizedBox(
      height: btnSize,
      child: ElevatedButton.icon(
        onPressed: () {
          widget.ctx.eventBus.publish(
            channel,
            EventPayload(
              type: 'workflow.action',
              sourceWidgetId: widget.node.id,
              data: payload,
            ),
          );
        },
        icon: Icon(icon, size: theme.window.toolbarButtonIconSize),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          minimumSize: Size(0, btnSize),
          padding: EdgeInsets.symmetric(horizontal: theme.spacing.sm),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(theme.window.toolbarButtonRadius),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Popover
// ---------------------------------------------------------------------------

Widget _buildPopover(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  return _PopoverWidget(
    key: ValueKey('popover-${node.id}'),
    node: node,
    ctx: ctx,
    children: children,
  );
}

class _PopoverWidget extends StatefulWidget {
  final SduiNode node;
  final SduiRenderContext ctx;
  final List<Widget> children;

  const _PopoverWidget({
    super.key,
    required this.node,
    required this.ctx,
    required this.children,
  });

  @override
  State<_PopoverWidget> createState() => _PopoverWidgetState();
}

class _PopoverWidgetState extends State<_PopoverWidget> {
  final _triggerKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  void _toggle() {
    if (_overlayEntry != null) {
      _dismiss();
      return;
    }
    _show();
  }

  void _show() {
    final renderBox = _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final overlay = Overlay.of(context);
    final position = renderBox.localToGlobal(Offset.zero);
    final triggerSize = renderBox.size;
    final theme = widget.ctx.theme;
    final title = PropConverter.to<String>(widget.node.props['title']);
    final width = PropConverter.to<double>(widget.node.props['width']) ?? 320.0;
    final maxHeight = PropConverter.to<double>(widget.node.props['maxHeight']) ?? 400.0;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        // Position below the trigger, aligned to left edge
        final screenSize = MediaQuery.of(context).size;
        double left = position.dx;
        double top = position.dy + triggerSize.height + 4;

        // Flip left if it would overflow right
        if (left + width > screenSize.width - 8) {
          left = position.dx + triggerSize.width - width;
          if (left < 8) left = 8;
        }
        // Flip up if it would overflow bottom
        if (top + maxHeight > screenSize.height - 8) {
          top = position.dy - maxHeight - 4;
          if (top < 8) top = position.dy + triggerSize.height + 4;
        }

        return Stack(
          children: [
            // Dismiss on outside tap
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _dismiss,
              ),
            ),
            Positioned(
              left: left,
              top: top,
              child: Material(
                elevation: theme.elevation.medium,
                borderRadius: BorderRadius.circular(theme.radius.md),
                color: Theme.of(context).colorScheme.surface,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: width,
                    maxHeight: maxHeight,
                  ),
                  child: SizedBox(
                    width: width,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (title != null) ...[
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                                theme.spacing.md, theme.spacing.sm,
                                theme.spacing.sm, theme.spacing.xs),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: theme.textStyles.resolve('labelLarge')?.toTextStyle(
                                          color: theme.colors.onSurface,
                                        ) ??
                                        TextStyle(
                                          fontSize: theme.textStyles.labelLarge.fontSize,
                                          fontWeight: FontWeight.w600,
                                          color: theme.colors.onSurface,
                                        ),
                                  ),
                                ),
                                SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    iconSize: theme.iconSize.sm,
                                    icon: Icon(FontAwesomeIcons.xmark,
                                        color: theme.colors.onSurfaceVariant),
                                    onPressed: _dismiss,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Divider(height: 1, color: theme.colors.outlineVariant),
                        ],
                        Flexible(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.all(theme.spacing.md),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: widget.children,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    overlay.insert(_overlayEntry!);
  }

  void _dismiss() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    widget.ctx.eventBus.publish(
      '${widget.node.id}.dismissed',
      EventPayload(
        type: 'popover.dismissed',
        sourceWidgetId: widget.node.id,
        data: {},
      ),
    );
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.ctx.theme;
    final iconName = PropConverter.to<String>(widget.node.props['icon']) ?? 'circle-info';
    final tooltip = PropConverter.to<String>(widget.node.props['tooltip']);
    final variant = PropConverter.to<String>(widget.node.props['variant']);
    final iconData = _iconMap[iconName] ?? FontAwesomeIcons.circleInfo;

    final isToolbar = variant == 'toolbar-primary' || variant == 'toolbar-secondary';
    final iconColor = isToolbar && variant == 'toolbar-primary'
        ? theme.colors.primary
        : theme.colors.onSurfaceVariant;
    final iconSize = isToolbar ? theme.iconSize.sm : theme.iconSize.md;

    Widget button = SizedBox(
      key: _triggerKey,
      width: isToolbar ? theme.window.toolbarButtonSize : null,
      height: isToolbar ? theme.window.toolbarButtonSize : null,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: iconSize,
        icon: Icon(iconData, color: iconColor),
        onPressed: _toggle,
        tooltip: tooltip,
        style: isToolbar
            ? IconButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(theme.radius.sm)),
              )
            : null,
      ),
    );

    return button;
  }
}

// ---------------------------------------------------------------------------
// ClipboardCopy
// ---------------------------------------------------------------------------

Widget _buildClipboardCopy(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  return _ClipboardCopyWidget(
    key: ValueKey('clipboard-${node.id}'),
    node: node,
    ctx: ctx,
  );
}

class _ClipboardCopyWidget extends StatefulWidget {
  final SduiNode node;
  final SduiRenderContext ctx;

  const _ClipboardCopyWidget({
    super.key,
    required this.node,
    required this.ctx,
  });

  @override
  State<_ClipboardCopyWidget> createState() => _ClipboardCopyWidgetState();
}

class _ClipboardCopyWidgetState extends State<_ClipboardCopyWidget> {
  bool _copied = false;

  Future<void> _copy() async {
    final text = PropConverter.to<String>(widget.node.props['text']) ?? '';
    await Clipboard.setData(ClipboardData(text: text));
    setState(() => _copied = true);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.ctx.theme;
    final iconName = PropConverter.to<String>(widget.node.props['icon']) ?? 'copy';
    final confirmIconName = PropConverter.to<String>(widget.node.props['confirmIcon']) ?? 'check';
    final tooltip = PropConverter.to<String>(widget.node.props['tooltip']) ?? 'Copy';
    final size = PropConverter.to<double>(widget.node.props['size']) ?? theme.iconSize.sm;

    final currentIcon = _copied ? confirmIconName : iconName;
    final iconData = _iconMap[currentIcon] ?? FontAwesomeIcons.copy;
    final color = _copied ? theme.colors.success : theme.colors.onSurfaceVariant;

    return SizedBox(
      width: size + 8,
      height: size + 8,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: size,
        icon: Icon(iconData, color: color),
        onPressed: _copy,
        tooltip: _copied ? 'Copied!' : tooltip,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ImageViewer
// ---------------------------------------------------------------------------

Widget _buildImageViewer(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  final rawUrl = PropConverter.to<String>(node.props['url']) ?? '';
  final url = rawUrl.isEmpty ? rawUrl : _resolveAssetUrl(rawUrl, ctx.catalogBaseUrl);
  if (url.isEmpty) {
    return Center(
      child: Text('No image URL', style: TextStyle(color: ctx.theme.colors.onSurfaceMuted)),
    );
  }

  return InteractiveViewer(
    minScale: 0.1,
    maxScale: 5.0,
    boundaryMargin: const EdgeInsets.all(100),
    child: Center(
      child: Image.network(
        url,
        // Auth token should be baked into the URL query params
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          final pct = progress.expectedTotalBytes != null
              ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
              : null;
          return Center(
            child: CircularProgressIndicator(value: pct),
          );
        },
        errorBuilder: (context, error, stack) {
          debugPrint('[ImageViewer] Failed to load $url: $error');
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FontAwesomeIcons.image, size: ctx.theme.window.bodyStateIconSize,
                    color: ctx.theme.colors.onSurfaceMuted),
                SizedBox(height: ctx.theme.spacing.sm),
                Text('Failed to load image',
                    style: TextStyle(color: ctx.theme.colors.onSurfaceMuted)),
                SizedBox(height: ctx.theme.spacing.xs),
                SelectableText(error.toString(),
                    style: TextStyle(fontSize: ctx.theme.textStyles.micro.fontSize, color: ctx.theme.colors.error)),
              ],
            ),
          );
        },
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// TabbedImageViewer
// ---------------------------------------------------------------------------

Widget _buildTabbedImageViewer(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  final images = node.props['images'];
  if (images is! List || images.isEmpty) {
    return Center(
      child: Text('No images', style: TextStyle(color: ctx.theme.colors.onSurfaceMuted)),
    );
  }

  final authToken = PropConverter.to<String>(node.props['authToken']);

  final imageDefs = <_ImageDef>[];
  for (final img in images) {
    if (img is Map) {
      final rawUrl = PropConverter.to<String>(img['url']) ?? '';
      imageDefs.add(_ImageDef(
        filename: PropConverter.to<String>(img['filename']) ?? '',
        mimetype: PropConverter.to<String>(img['mimetype']) ?? '',
        url: rawUrl.isEmpty ? rawUrl : _resolveAssetUrl(rawUrl, ctx.catalogBaseUrl),
        schemaId: PropConverter.to<String>(img['schemaId']) ?? '',
      ));
    }
  }

  if (imageDefs.isEmpty) {
    return Center(
      child: Text('No images', style: TextStyle(color: ctx.theme.colors.onSurfaceMuted)),
    );
  }

  return _TabbedImageViewerWidget(
    key: ValueKey('tiv-${node.id}'),
    images: imageDefs,
    authToken: authToken,
    theme: ctx.theme,
  );
}

class _ImageDef {
  final String filename, mimetype, url, schemaId;
  _ImageDef({required this.filename, required this.mimetype,
    required this.url, required this.schemaId});
}

class _TabbedImageViewerWidget extends StatefulWidget {
  final List<_ImageDef> images;
  final String? authToken;
  final SduiTheme theme;

  const _TabbedImageViewerWidget({
    super.key,
    required this.images,
    required this.authToken,
    required this.theme,
  });

  @override
  State<_TabbedImageViewerWidget> createState() => _TabbedImageViewerState();
}

class _TabbedImageViewerState extends State<_TabbedImageViewerWidget> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final images = widget.images;
    if (_selectedTab >= images.length) _selectedTab = 0;
    final current = images[_selectedTab];

    final tabStyle = theme.textStyles.resolve('labelSmall')?.toTextStyle(
          color: theme.colors.onSurface,
        ) ??
        TextStyle(fontSize: theme.textStyles.labelSmall.fontSize, color: theme.colors.onSurface);
    final tabInactive = tabStyle.copyWith(color: theme.colors.onSurfaceVariant);
    final infoStyle = TextStyle(fontSize: theme.textStyles.micro.fontSize, color: theme.colors.onSurfaceMuted);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tab bar (only if multiple images)
        if (images.length > 1)
          Container(
            color: theme.colors.surfaceContainerHigh,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < images.length; i++)
                    GestureDetector(
                      onTap: () => setState(() => _selectedTab = i),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: theme.internalTab.paddingH, vertical: theme.internalTab.paddingV),
                        decoration: BoxDecoration(
                          color: i == _selectedTab ? theme.colors.surface : Colors.transparent,
                          border: Border(
                            bottom: BorderSide(
                              color: i == _selectedTab ? theme.colors.primary : Colors.transparent,
                              width: theme.internalTab.activeBorderWidth,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(FontAwesomeIcons.image, size: theme.internalTab.iconSize,
                                color: i == _selectedTab
                                    ? theme.colors.primary
                                    : theme.colors.onSurfaceMuted),
                            SizedBox(width: theme.spacing.xs),
                            Text(
                              images[i].filename.isNotEmpty
                                  ? images[i].filename
                                  : 'Image ${i + 1}',
                              style: i == _selectedTab ? tabStyle : tabInactive,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        // Info bar
        Container(
          color: theme.colors.surfaceContainerLow,
          padding: EdgeInsets.symmetric(horizontal: theme.dataTable.cellPaddingH, vertical: theme.dataTable.cellPaddingV),
          child: Row(
            children: [
              Text(current.mimetype, style: infoStyle),
              const Spacer(),
              Text(current.filename, style: infoStyle),
            ],
          ),
        ),
        Divider(height: 1, color: theme.colors.outlineVariant),
        // Image
        Expanded(
          child: Container(
            color: theme.colors.surfaceContainerLowest,
            child: InteractiveViewer(
              minScale: 0.1,
              maxScale: 5.0,
              boundaryMargin: const EdgeInsets.all(100),
              child: Center(
                child: Image.network(
                  current.url,
                  // Auth token is baked into the URL query params by the dispatcher
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    final pct = progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                        : null;
                    return Center(child: CircularProgressIndicator(value: pct));
                  },
                  errorBuilder: (context, error, stack) {
                    debugPrint('[TabbedImageViewer] Failed to load ${current.filename}: $error');
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(FontAwesomeIcons.image, size: theme.window.bodyStateIconSize,
                              color: theme.colors.onSurfaceMuted),
                          SizedBox(height: theme.spacing.sm),
                          Text('Failed to load image',
                              style: TextStyle(color: theme.colors.onSurfaceMuted)),
                          SizedBox(height: theme.spacing.xs),
                          SelectableText(error.toString(),
                              style: TextStyle(fontSize: theme.textStyles.micro.fontSize, color: theme.colors.error)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// AnnotatedImageViewer
// ---------------------------------------------------------------------------

Widget _buildAnnotatedImageViewer(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  final images = node.props['images'];
  if (images is! List || images.isEmpty) {
    return Center(
      child: Text('No images', style: TextStyle(color: ctx.theme.colors.onSurfaceMuted)),
    );
  }

  final authToken = PropConverter.to<String>(node.props['authToken']);
  final sendChannel = PropConverter.to<String>(node.props['sendChannel']) ?? 'visualization.annotations.send';
  final annotationColorHex = PropConverter.to<String>(node.props['annotationColor']) ?? '#FF5722';

  final imageDefs = <_ImageDef>[];
  for (final img in images) {
    if (img is Map) {
      final rawUrl = PropConverter.to<String>(img['url']) ?? '';
      imageDefs.add(_ImageDef(
        filename: PropConverter.to<String>(img['filename']) ?? '',
        mimetype: PropConverter.to<String>(img['mimetype']) ?? '',
        url: rawUrl.isEmpty ? rawUrl : _resolveAssetUrl(rawUrl, ctx.catalogBaseUrl),
        schemaId: PropConverter.to<String>(img['schemaId']) ?? '',
      ));
    }
  }

  if (imageDefs.isEmpty) {
    return Center(
      child: Text('No images', style: TextStyle(color: ctx.theme.colors.onSurfaceMuted)),
    );
  }

  return _AnnotatedImageViewerWidget(
    key: ValueKey('aiv-${node.id}'),
    images: imageDefs,
    authToken: authToken,
    sendChannel: sendChannel,
    annotationColorHex: annotationColorHex,
    theme: ctx.theme,
    eventBus: ctx.eventBus,
    sourceWidgetId: node.id,
  );
}

enum _DrawingTool { none, polygon, rectangle, circle, arrow, freehand, text }

class _Annotation {
  _DrawingTool type;
  List<Offset> points;
  double? radius;
  String? label;
  _Annotation({required this.type, List<Offset>? points, this.radius, this.label})
      : points = points ?? [];

  Rect get bounds {
    if (points.isEmpty) return Rect.zero;
    double minX = points.first.dx, maxX = minX, minY = points.first.dy, maxY = minY;
    for (final p in points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    if (type == _DrawingTool.circle && radius != null) {
      final c = points.first;
      return Rect.fromCircle(center: c, radius: radius!);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
    if (radius != null) 'radius': radius,
    if (label != null) 'label': label,
  };
}

class _AnnotatedImageViewerWidget extends StatefulWidget {
  final List<_ImageDef> images;
  final String? authToken;
  final String sendChannel;
  final String annotationColorHex;
  final SduiTheme theme;
  final dynamic eventBus;
  final String sourceWidgetId;

  const _AnnotatedImageViewerWidget({
    super.key,
    required this.images,
    required this.authToken,
    required this.sendChannel,
    required this.annotationColorHex,
    required this.theme,
    required this.eventBus,
    required this.sourceWidgetId,
  });

  @override
  State<_AnnotatedImageViewerWidget> createState() => _AnnotatedImageViewerState();
}

class _AnnotatedImageViewerState extends State<_AnnotatedImageViewerWidget> {
  int _selectedTab = 0;
  _DrawingTool _activeTool = _DrawingTool.none;

  // Per-tab annotation lists
  final Map<int, List<_Annotation>> _annotations = {};

  // In-progress drawing state
  List<Offset> _currentPoints = [];
  bool _isDrawing = false;
  int? _movingAnnotationIdx;
  Offset? _moveStart;

  // Text input
  bool _showTextInput = false;
  Offset? _textAnchor;
  final _textController = TextEditingController();
  final _textFocusNode = FocusNode();

  // Zoom/pan
  final TransformationController _transformCtrl = TransformationController();

  List<_Annotation> get _currentAnnotations =>
      _annotations.putIfAbsent(_selectedTab, () => []);

  Color get _annotationColor {
    final hex = widget.annotationColorHex.replaceFirst('#', '');
    if (hex.length == 6) return Color(int.parse('FF$hex', radix: 16));
    if (hex.length == 8) return Color(int.parse(hex, radix: 16));
    return const Color(0xFFFF5722);
  }

  void _selectTool(_DrawingTool tool) {
    setState(() {
      _activeTool = _activeTool == tool ? _DrawingTool.none : tool;
      _currentPoints = [];
      _isDrawing = false;
      _showTextInput = false;
    });
  }

  void _clearAnnotations() {
    setState(() {
      _currentAnnotations.clear();
    });
  }

  void _sendToChat() {
    final annots = _currentAnnotations;
    if (annots.isEmpty) return;
    final current = widget.images[_selectedTab];
    widget.eventBus.publish(
      widget.sendChannel,
      EventPayload(
        type: 'annotationBundle',
        sourceWidgetId: widget.sourceWidgetId,
        data: {
          'annotations': annots.map((a) => a.toJson()).toList(),
          'sourceImage': {
            'schemaId': current.schemaId,
            'filename': current.filename,
            'url': current.url,
          },
        },
      ),
    );
  }

  void _onPanStart(DragStartDetails details) {
    if (_activeTool == _DrawingTool.none) {
      // Check if tapping an existing annotation to move it
      final localPos = _screenToImage(details.localPosition);
      final hitIdx = _hitTest(localPos);
      if (hitIdx != null) {
        setState(() {
          _movingAnnotationIdx = hitIdx;
          _moveStart = localPos;
        });
        return;
      }
      return; // Let InteractiveViewer handle pan
    }
    final pos = _screenToImage(details.localPosition);
    setState(() {
      _isDrawing = true;
      _currentPoints = [pos];
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final pos = _screenToImage(details.localPosition);
    if (_movingAnnotationIdx != null && _moveStart != null) {
      final dx = pos.dx - _moveStart!.dx;
      final dy = pos.dy - _moveStart!.dy;
      setState(() {
        final annot = _currentAnnotations[_movingAnnotationIdx!];
        annot.points = annot.points.map((p) => Offset(p.dx + dx, p.dy + dy)).toList();
        _moveStart = pos;
      });
      return;
    }
    if (!_isDrawing) return;
    setState(() {
      switch (_activeTool) {
        case _DrawingTool.freehand:
          _currentPoints.add(pos);
        case _DrawingTool.rectangle:
        case _DrawingTool.circle:
        case _DrawingTool.arrow:
          if (_currentPoints.length == 1) {
            _currentPoints.add(pos);
          } else {
            _currentPoints[1] = pos;
          }
        default:
          break;
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_movingAnnotationIdx != null) {
      setState(() {
        _movingAnnotationIdx = null;
        _moveStart = null;
      });
      return;
    }
    if (!_isDrawing || _currentPoints.length < 2) {
      setState(() { _isDrawing = false; _currentPoints = []; });
      return;
    }
    setState(() {
      switch (_activeTool) {
        case _DrawingTool.rectangle:
          _currentAnnotations.add(_Annotation(
            type: _DrawingTool.rectangle,
            points: List.from(_currentPoints),
          ));
        case _DrawingTool.circle:
          final center = _currentPoints[0];
          final edge = _currentPoints[1];
          final r = (center - edge).distance;
          _currentAnnotations.add(_Annotation(
            type: _DrawingTool.circle,
            points: [center],
            radius: r,
          ));
        case _DrawingTool.arrow:
          _currentAnnotations.add(_Annotation(
            type: _DrawingTool.arrow,
            points: List.from(_currentPoints),
          ));
        case _DrawingTool.freehand:
          _currentAnnotations.add(_Annotation(
            type: _DrawingTool.freehand,
            points: List.from(_currentPoints),
          ));
        default:
          break;
      }
      _isDrawing = false;
      _currentPoints = [];
    });
  }

  void _onTapUp(TapUpDetails details) {
    final pos = _screenToImage(details.localPosition);
    switch (_activeTool) {
      case _DrawingTool.polygon:
        setState(() {
          if (_currentPoints.isNotEmpty &&
              (_currentPoints.first - pos).distance < 15 &&
              _currentPoints.length >= 3) {
            // Close polygon
            _currentAnnotations.add(_Annotation(
              type: _DrawingTool.polygon,
              points: List.from(_currentPoints),
            ));
            _currentPoints = [];
          } else {
            _currentPoints.add(pos);
          }
        });
      case _DrawingTool.text:
        setState(() {
          _textAnchor = pos;
          _showTextInput = true;
          _textController.clear();
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _textFocusNode.requestFocus();
        });
      default:
        break;
    }
  }

  void _commitText() {
    if (_textAnchor != null && _textController.text.isNotEmpty) {
      setState(() {
        _currentAnnotations.add(_Annotation(
          type: _DrawingTool.text,
          points: [_textAnchor!],
          label: _textController.text,
        ));
        _showTextInput = false;
        _textAnchor = null;
      });
    } else {
      setState(() {
        _showTextInput = false;
        _textAnchor = null;
      });
    }
  }

  Offset _screenToImage(Offset screenPos) {
    // Inverse of the transform controller to get image-space coords
    final matrix = _transformCtrl.value;
    final inv = Matrix4.inverted(matrix);
    final v = inv.transform3(Vector3(screenPos.dx, screenPos.dy, 0));
    return Offset(v.x, v.y);
  }

  int? _hitTest(Offset pos) {
    for (var i = _currentAnnotations.length - 1; i >= 0; i--) {
      final a = _currentAnnotations[i];
      final threshold = 15.0;
      final r = a.bounds.inflate(threshold);
      if (r.contains(pos)) return i;
    }
    return null;
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final images = widget.images;
    if (_selectedTab >= images.length) _selectedTab = 0;
    final current = images[_selectedTab];
    final hasAnnotations = _currentAnnotations.isNotEmpty;

    final tabStyle = theme.textStyles.resolve('labelSmall')?.toTextStyle(
          color: theme.colors.onSurface,
        ) ??
        TextStyle(fontSize: theme.textStyles.labelSmall.fontSize, color: theme.colors.onSurface);
    final tabInactive = tabStyle.copyWith(color: theme.colors.onSurfaceVariant);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Toolbar — drawing tools | actions | zoom
        Container(
          height: theme.window.toolbarHeight,
          color: theme.colors.surface,
          padding: EdgeInsets.symmetric(horizontal: theme.spacing.sm),
          child: Row(
            children: [
              // Drawing tools
              for (final tool in [
                (_DrawingTool.polygon, FontAwesomeIcons.drawPolygon, 'Polygon'),
                (_DrawingTool.rectangle, FontAwesomeIcons.square, 'Rectangle'),
                (_DrawingTool.circle, FontAwesomeIcons.circle, 'Circle'),
                (_DrawingTool.arrow, FontAwesomeIcons.arrowRight, 'Arrow'),
                (_DrawingTool.freehand, FontAwesomeIcons.pencil, 'Freehand'),
                (_DrawingTool.text, FontAwesomeIcons.font, 'Text'),
              ]) ...[
                _toolButton(tool.$1, tool.$2, tool.$3, theme),
                SizedBox(width: theme.spacing.xs),
              ],
              const Spacer(),
              // Actions
              _actionButton(FontAwesomeIcons.trashCan, 'Clear all', hasAnnotations, _clearAnnotations, theme),
              SizedBox(width: theme.spacing.xs),
              _actionButton(FontAwesomeIcons.paperPlane, 'Send to Chat', hasAnnotations, _sendToChat, theme),
              SizedBox(width: theme.spacing.xs),
              _actionButton(FontAwesomeIcons.floppyDisk, 'Save', true, () {/* save handled by browser */}, theme),
              const Spacer(),
              // Zoom
              _actionButton(FontAwesomeIcons.magnifyingGlassPlus, 'Zoom in', true, () {
                final m = _transformCtrl.value.clone()..scale(1.25);
                _transformCtrl.value = m;
              }, theme),
              SizedBox(width: theme.spacing.xs),
              _actionButton(FontAwesomeIcons.magnifyingGlassMinus, 'Zoom out', true, () {
                final m = _transformCtrl.value.clone()..scale(0.8);
                _transformCtrl.value = m;
              }, theme),
              SizedBox(width: theme.spacing.xs),
              _actionButton(FontAwesomeIcons.upRightAndDownLeftFromCenter, 'Fit', true, () {
                _transformCtrl.value = Matrix4.identity();
              }, theme),
            ],
          ),
        ),
        Divider(height: 1, color: theme.colors.outlineVariant),
        // Tab bar (only if multiple images)
        if (images.length > 1)
          Container(
            color: theme.colors.surfaceContainerHigh,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < images.length; i++)
                    GestureDetector(
                      onTap: () => setState(() => _selectedTab = i),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: theme.internalTab.paddingH,
                            vertical: theme.internalTab.paddingV),
                        decoration: BoxDecoration(
                          color: i == _selectedTab ? theme.colors.surface : Colors.transparent,
                          border: Border(
                            bottom: BorderSide(
                              color: i == _selectedTab ? theme.colors.primary : Colors.transparent,
                              width: theme.internalTab.activeBorderWidth,
                            ),
                          ),
                        ),
                        child: Text(
                          images[i].filename.isNotEmpty ? images[i].filename : 'Image ${i + 1}',
                          style: i == _selectedTab ? tabStyle : tabInactive,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        // Canvas area
        Expanded(
          child: Stack(
            children: [
              // Image + annotation overlay in InteractiveViewer
              GestureDetector(
                onPanStart: _activeTool != _DrawingTool.none || _movingAnnotationIdx != null
                    ? _onPanStart : null,
                onPanUpdate: _activeTool != _DrawingTool.none || _movingAnnotationIdx != null
                    ? _onPanUpdate : null,
                onPanEnd: _activeTool != _DrawingTool.none || _movingAnnotationIdx != null
                    ? _onPanEnd : null,
                onTapUp: (_activeTool == _DrawingTool.polygon || _activeTool == _DrawingTool.text)
                    ? _onTapUp : null,
                child: InteractiveViewer(
                  transformationController: _transformCtrl,
                  constrained: false,
                  minScale: 0.1,
                  maxScale: 10.0,
                  boundaryMargin: const EdgeInsets.all(200),
                  panEnabled: _activeTool == _DrawingTool.none && _movingAnnotationIdx == null,
                  scaleEnabled: _activeTool == _DrawingTool.none,
                  child: Stack(
                    children: [
                      Image.network(
                        current.url,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          final pct = progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                              : null;
                          return Center(child: CircularProgressIndicator(value: pct));
                        },
                        errorBuilder: (context, error, stack) => Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(FontAwesomeIcons.image, size: 48, color: theme.colors.onSurfaceMuted),
                              SizedBox(height: theme.spacing.sm),
                              Text('Failed to load image', style: TextStyle(color: theme.colors.onSurfaceMuted)),
                            ],
                          ),
                        ),
                      ),
                      // Annotation paint overlay
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _AnnotationPainter(
                            annotations: _currentAnnotations,
                            inProgressPoints: _currentPoints,
                            inProgressTool: _activeTool,
                            movingIdx: _movingAnnotationIdx,
                            annotationColor: _annotationColor,
                            textFontSize: widget.theme.textStyles.bodyMedium.fontSize,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Text input overlay
              if (_showTextInput && _textAnchor != null)
                Positioned(
                  left: 20,
                  top: 20,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(theme.radius.sm),
                    child: SizedBox(
                      width: 200,
                      child: TextField(
                        controller: _textController,
                        focusNode: _textFocusNode,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Enter text...',
                          isDense: true,
                          contentPadding: EdgeInsets.all(theme.spacing.sm),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(theme.radius.sm),
                          ),
                        ),
                        onSubmitted: (_) => _commitText(),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _toolButton(_DrawingTool tool, IconData icon, String tooltip, SduiTheme theme) {
    final isActive = _activeTool == tool;
    return SizedBox(
      width: theme.window.toolbarButtonSize,
      height: theme.window.toolbarButtonSize,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: theme.iconSize.sm,
        tooltip: tooltip,
        icon: Icon(icon, color: isActive ? theme.colors.onPrimary : theme.colors.primary),
        style: IconButton.styleFrom(
          backgroundColor: isActive ? theme.colors.primary : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(theme.radius.sm),
            side: isActive
                ? BorderSide.none
                : BorderSide(color: theme.colors.primary, width: theme.window.toolbarButtonBorderWidth),
          ),
        ),
        onPressed: () => _selectTool(tool),
      ),
    );
  }

  Widget _actionButton(IconData icon, String tooltip, bool enabled, VoidCallback onPressed, SduiTheme theme) {
    return SizedBox(
      width: theme.window.toolbarButtonSize,
      height: theme.window.toolbarButtonSize,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: theme.iconSize.sm,
        tooltip: tooltip,
        icon: Icon(icon, color: enabled ? theme.colors.primary : theme.colors.onSurfaceMuted),
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(theme.radius.sm),
            side: BorderSide(color: enabled ? theme.colors.primary : theme.colors.outlineVariant, width: theme.window.toolbarButtonBorderWidth),
          ),
        ),
        onPressed: enabled ? onPressed : null,
      ),
    );
  }
}

class _AnnotationPainter extends CustomPainter {
  final List<_Annotation> annotations;
  final List<Offset> inProgressPoints;
  final _DrawingTool inProgressTool;
  final int? movingIdx;
  final Color annotationColor;
  final double textFontSize;

  _AnnotationPainter({
    required this.annotations,
    required this.inProgressPoints,
    required this.inProgressTool,
    this.movingIdx,
    required this.annotationColor,
    required this.textFontSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = annotationColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final fill = Paint()
      ..color = annotationColor.withAlpha(50)
      ..style = PaintingStyle.fill;
    final movingStroke = Paint()
      ..color = const Color(0xFF2196F3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw completed annotations
    for (var i = 0; i < annotations.length; i++) {
      final a = annotations[i];
      final s = i == movingIdx ? movingStroke : stroke;
      _drawAnnotation(canvas, a, s, fill);
    }

    // Draw in-progress shape
    if (inProgressPoints.isNotEmpty) {
      final ghost = Paint()
        ..color = annotationColor.withAlpha(128)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final ghostFill = Paint()
        ..color = annotationColor.withAlpha(25)
        ..style = PaintingStyle.fill;

      switch (inProgressTool) {
        case _DrawingTool.polygon:
          if (inProgressPoints.length >= 2) {
            final path = Path()..moveTo(inProgressPoints.first.dx, inProgressPoints.first.dy);
            for (final p in inProgressPoints.skip(1)) path.lineTo(p.dx, p.dy);
            canvas.drawPath(path, ghost);
          }
          for (final p in inProgressPoints) {
            canvas.drawCircle(p, 4, ghost);
          }
        case _DrawingTool.rectangle:
          if (inProgressPoints.length == 2) {
            final rect = Rect.fromPoints(inProgressPoints[0], inProgressPoints[1]);
            canvas.drawRect(rect, ghostFill);
            canvas.drawRect(rect, ghost);
          }
        case _DrawingTool.circle:
          if (inProgressPoints.length == 2) {
            final r = (inProgressPoints[0] - inProgressPoints[1]).distance;
            canvas.drawCircle(inProgressPoints[0], r, ghostFill);
            canvas.drawCircle(inProgressPoints[0], r, ghost);
          }
        case _DrawingTool.arrow:
          if (inProgressPoints.length == 2) {
            _drawArrow(canvas, inProgressPoints[0], inProgressPoints[1], ghost);
          }
        case _DrawingTool.freehand:
          if (inProgressPoints.length >= 2) {
            final path = Path()..moveTo(inProgressPoints.first.dx, inProgressPoints.first.dy);
            for (final p in inProgressPoints.skip(1)) path.lineTo(p.dx, p.dy);
            canvas.drawPath(path, ghost);
          }
        default:
          break;
      }
    }
  }

  void _drawAnnotation(Canvas canvas, _Annotation a, Paint stroke, Paint fill) {
    switch (a.type) {
      case _DrawingTool.polygon:
        if (a.points.length >= 2) {
          final path = Path()..moveTo(a.points.first.dx, a.points.first.dy);
          for (final p in a.points.skip(1)) path.lineTo(p.dx, p.dy);
          path.close();
          canvas.drawPath(path, fill);
          canvas.drawPath(path, stroke);
        }
      case _DrawingTool.rectangle:
        if (a.points.length == 2) {
          final rect = Rect.fromPoints(a.points[0], a.points[1]);
          canvas.drawRect(rect, fill);
          canvas.drawRect(rect, stroke);
        }
      case _DrawingTool.circle:
        if (a.points.isNotEmpty && a.radius != null) {
          canvas.drawCircle(a.points[0], a.radius!, fill);
          canvas.drawCircle(a.points[0], a.radius!, stroke);
        }
      case _DrawingTool.arrow:
        if (a.points.length == 2) {
          _drawArrow(canvas, a.points[0], a.points[1], stroke);
        }
      case _DrawingTool.freehand:
        if (a.points.length >= 2) {
          final path = Path()..moveTo(a.points.first.dx, a.points.first.dy);
          for (final p in a.points.skip(1)) path.lineTo(p.dx, p.dy);
          canvas.drawPath(path, stroke);
        }
      case _DrawingTool.text:
        if (a.points.isNotEmpty && a.label != null) {
          final tp = TextPainter(
            text: TextSpan(
              text: a.label!,
              style: TextStyle(color: annotationColor, fontSize: textFontSize, fontWeight: FontWeight.w600),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, a.points.first);
        }
      default:
        break;
    }
  }

  void _drawArrow(Canvas canvas, Offset from, Offset to, Paint paint) {
    canvas.drawLine(from, to, paint);
    // Arrowhead
    final dir = (to - from);
    final len = dir.distance;
    if (len < 1) return;
    final unit = dir / len;
    final headLen = len * 0.3 > 20 ? 20.0 : len * 0.3;
    final headW = headLen * 0.5;
    final perp = Offset(-unit.dy, unit.dx);
    final p1 = to - unit * headLen + perp * headW;
    final p2 = to - unit * headLen - perp * headW;
    final path = Path()..moveTo(to.dx, to.dy)..lineTo(p1.dx, p1.dy)..lineTo(p2.dx, p2.dy)..close();
    canvas.drawPath(path, Paint()..color = paint.color..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant _AnnotationPainter old) => true;
}

// ---------------------------------------------------------------------------
// DirectedGraph
// ---------------------------------------------------------------------------

Widget _buildDirectedGraph(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  final nodesRaw = node.props['nodes'];
  final edgesRaw = node.props['edges'];
  if (nodesRaw is! List || nodesRaw.isEmpty) {
    final emptyIconName = PropConverter.to<String>(node.props['emptyIcon']);
    final emptyTitle = PropConverter.to<String>(node.props['emptyTitle']);
    final emptySubtitle = PropConverter.to<String>(node.props['emptySubtitle']);
    final emptyIcon = emptyIconName != null ? _iconMap[emptyIconName] : null;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emptyIcon != null)
            Icon(emptyIcon, size: 48, color: ctx.theme.colors.onSurfaceMuted),
          if (emptyIcon != null) SizedBox(height: ctx.theme.spacing.sm + 4),
          Text(
            emptyTitle ?? 'No nodes',
            style: ctx.theme.textStyles.resolve('bodyMedium')?.toTextStyle(
                  color: ctx.theme.colors.onSurfaceMuted,
                ) ??
                TextStyle(color: ctx.theme.colors.onSurfaceMuted),
          ),
          if (emptySubtitle != null && emptySubtitle.isNotEmpty) ...[
            SizedBox(height: ctx.theme.spacing.xs),
            Text(
              emptySubtitle,
              style: ctx.theme.textStyles.resolve('bodySmall')?.toTextStyle(
                    color: ctx.theme.colors.onSurfaceMuted,
                  ) ??
                  TextStyle(fontSize: 12, color: ctx.theme.colors.onSurfaceMuted),
            ),
          ],
        ],
      ),
    );
  }

  final channel = PropConverter.to<String>(node.props['channel']) ?? 'graph.selection';
  final doubleTapChannel = PropConverter.to<String>(node.props['doubleTapChannel']);
  final zoomInChannel = PropConverter.to<String>(node.props['zoomInChannel']);
  final zoomOutChannel = PropConverter.to<String>(node.props['zoomOutChannel']);
  final fitToWindowChannel = PropConverter.to<String>(node.props['fitToWindowChannel']);
  final stepStateChannel = PropConverter.to<String>(node.props['stepStateChannel']);
  final searchQuery = PropConverter.to<String>(node.props['searchQuery']) ?? '';
  final searchChannel = PropConverter.to<String>(node.props['searchChannel']);

  // Parse nodes
  final graphNodes = <_GraphNode>[];
  for (final n in nodesRaw) {
    if (n is Map) {
      graphNodes.add(_GraphNode(
        id: PropConverter.to<String>(n['id']) ?? '',
        label: PropConverter.to<String>(n['label']) ?? '',
        x: PropConverter.to<double>(n['x']) ?? 0,
        y: PropConverter.to<double>(n['y']) ?? 0,
        width: PropConverter.to<double>(n['width']) ?? 0,
        height: PropConverter.to<double>(n['height']) ?? 36,
        shape: PropConverter.to<String>(n['shape']) ?? 'roundedRect',
        icon: PropConverter.to<String>(n['icon']) ?? '',
        iconColor: PropConverter.to<String>(n['iconColor']) ?? 'onSurfaceVariant',
        fill: PropConverter.to<String>(n['fill']) ?? 'surface',
        borderColor: PropConverter.to<String>(n['borderColor']) ?? 'outline',
        subtitle: PropConverter.to<String>(n['subtitle']),
        labelPosition: PropConverter.to<String>(n['labelPosition']) ?? 'inside',
      ));
    }
  }

  // Parse edges
  final graphEdges = <_GraphEdge>[];
  if (edgesRaw is List) {
    for (final e in edgesRaw) {
      if (e is Map) {
        graphEdges.add(_GraphEdge(
          from: PropConverter.to<String>(e['from']) ?? '',
          to: PropConverter.to<String>(e['to']) ?? '',
        ));
      }
    }
  }

  return _DirectedGraphWidget(
    key: ValueKey('dg-${node.id}'),
    nodes: graphNodes,
    edges: graphEdges,
    channel: channel,
    doubleTapChannel: doubleTapChannel,
    zoomInChannel: zoomInChannel,
    zoomOutChannel: zoomOutChannel,
    fitToWindowChannel: fitToWindowChannel,
    stepStateChannel: stepStateChannel,
    searchQuery: searchQuery,
    searchChannel: searchChannel,
    theme: ctx.theme,
    eventBus: ctx.eventBus,
    sourceWidgetId: node.id,
  );
}

class _GraphNode {
  final String id, label, shape, icon, iconColor, fill, borderColor;
  final String? subtitle;
  final String labelPosition; // 'inside' (default) or 'outside'
  final double x, y, width, height;
  _GraphNode({
    required this.id, required this.label,
    required this.x, required this.y,
    required this.width, required this.height,
    required this.shape, required this.icon,
    required this.iconColor, required this.fill,
    required this.borderColor, this.subtitle,
    this.labelPosition = 'inside',
  });
}

class _GraphEdge {
  final String from, to;
  _GraphEdge({required this.from, required this.to});
}

class _DirectedGraphWidget extends StatefulWidget {
  final List<_GraphNode> nodes;
  final List<_GraphEdge> edges;
  final String channel;
  final String? doubleTapChannel;
  final String? zoomInChannel;
  final String? zoomOutChannel;
  final String? fitToWindowChannel;
  final String? stepStateChannel;
  final String searchQuery;
  final String? searchChannel;
  final SduiTheme theme;
  final dynamic eventBus;
  final String sourceWidgetId;

  const _DirectedGraphWidget({
    super.key,
    required this.nodes,
    required this.edges,
    required this.channel,
    this.doubleTapChannel,
    this.zoomInChannel,
    this.zoomOutChannel,
    this.fitToWindowChannel,
    this.stepStateChannel,
    this.searchQuery = '',
    this.searchChannel,
    required this.theme,
    required this.eventBus,
    required this.sourceWidgetId,
  });

  @override
  State<_DirectedGraphWidget> createState() => _DirectedGraphWidgetState();
}

class _DirectedGraphWidgetState extends State<_DirectedGraphWidget> {
  String? _selectedId;
  final TransformationController _transformCtrl = TransformationController();
  final List<StreamSubscription> _subs = [];
  bool _initialFitApplied = false;
  Size _viewportSize = Size.zero;

  /// Live iconColor overrides from stepStateChanged events.
  /// Key: nodeId, Value: new iconColor token (e.g. 'info', 'success', 'error').
  final Map<String, String> _iconColorOverrides = {};

  /// Live search query from searchChannel events.
  String _liveSearchQuery = '';

  // Zoom constants matching standalone mock
  static const double _zoomStep = 1.25;
  static const double _minScale = 0.1;
  static const double _maxScale = 5.0;

  @override
  void initState() {
    super.initState();
    _subscribeChannels();
    _autoSelectRoot();
  }

  /// Auto-select the first node (workflow root) on load and publish selection.
  void _autoSelectRoot() {
    if (widget.nodes.isEmpty) return;
    final root = widget.nodes.first;
    _selectedId = root.id;
    // Publish after the frame so listeners are ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.eventBus.publish(
        widget.channel,
        EventPayload(
          type: 'selection',
          sourceWidgetId: widget.sourceWidgetId,
          data: {
            'nodeId': root.id,
            'label': root.label,
            'iconColor': _effectiveIconColor(root),
            'shape': root.shape,
            'subtitle': root.subtitle,
          },
        ),
      );
    });
  }

  void _subscribeChannels() {
    final bus = widget.eventBus;
    if (bus == null) return;
    void sub(String? ch, void Function() action) {
      if (ch == null || ch.isEmpty) return;
      _subs.add(bus.subscribe(ch).listen((_) => action()));
    }
    sub(widget.zoomInChannel, _zoomIn);
    sub(widget.zoomOutChannel, _zoomOut);
    sub(widget.fitToWindowChannel, _fitToWindow);

    // Live search from toolbar: {value}
    final sCh = widget.searchChannel;
    if (sCh != null && sCh.isNotEmpty) {
      _subs.add(bus.subscribe(sCh).listen((event) {
        final value = event.data['value']?.toString() ?? '';
        if (value != _liveSearchQuery) {
          setState(() => _liveSearchQuery = value);
        }
      }));
    }

    // Incremental step state updates: {nodeId, iconColor}
    final stCh = widget.stepStateChannel;
    if (stCh != null && stCh.isNotEmpty) {
      _subs.add(bus.subscribe(stCh).listen((event) {
        final nodeId = event.data['nodeId']?.toString();
        final iconColor = event.data['iconColor']?.toString();
        if (nodeId != null && iconColor != null) {
          setState(() => _iconColorOverrides[nodeId] = iconColor);
        }
      }));
    }
  }

  /// Get effective iconColor for a node — override takes priority.
  String _effectiveIconColor(_GraphNode node) {
    return _iconColorOverrides[node.id] ?? node.iconColor;
  }

  double get _currentScale => _transformCtrl.value.getMaxScaleOnAxis();

  void _zoomIn() {
    final scale = (_currentScale * _zoomStep).clamp(_minScale, _maxScale);
    _applyScale(scale);
  }

  void _zoomOut() {
    final scale = (_currentScale / _zoomStep).clamp(_minScale, _maxScale);
    _applyScale(scale);
  }

  void _applyScale(double newScale) {
    final matrix = _transformCtrl.value;
    final oldScale = matrix.getMaxScaleOnAxis();
    if (oldScale == 0) return;
    final ratio = newScale / oldScale;
    // Preserve current pan offset, only change scale
    final tx = matrix.storage[12] * ratio;
    final ty = matrix.storage[13] * ratio;
    final m = Matrix4.diagonal3Values(newScale, newScale, 1.0);
    m.storage[12] = tx;
    m.storage[13] = ty;
    _transformCtrl.value = m;
  }

  void _fitToWindow() {
    if (widget.nodes.isEmpty || _viewportSize == Size.zero) return;
    final rect = _nodesBoundingRect();
    if (rect.width <= 0 || rect.height <= 0) return;

    const padding = 40.0;
    final paddedW = rect.width + padding * 2;
    final paddedH = rect.height + padding * 2;

    final scaleX = _viewportSize.width / paddedW;
    final scaleY = _viewportSize.height / paddedH;
    final fitScale = (scaleX < scaleY ? scaleX : scaleY).clamp(_minScale, 1.0);

    // Center the content bounding rect in the viewport
    final scaledW = paddedW * fitScale;
    final scaledH = paddedH * fitScale;
    final tx = (_viewportSize.width - scaledW) / 2 - (rect.left - padding) * fitScale;
    final ty = (_viewportSize.height - scaledH) / 2 - (rect.top - padding) * fitScale;

    final m = Matrix4.identity();
    m.storage[12] = tx;
    m.storage[13] = ty;
    m.storage[0] = fitScale;
    m.storage[5] = fitScale;
    _transformCtrl.value = m;
  }

  /// Compute tight bounding rect around all nodes.
  Rect _nodesBoundingRect() {
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final n in widget.nodes) {
      final w = n.width > 0 ? n.width : 140.0;
      // Account for outside labels below the node
      final labelExtra = n.labelPosition == 'outside' ? 20.0 : 0.0;
      if (n.x < minX) minX = n.x;
      if (n.y < minY) minY = n.y;
      if (n.x + w > maxX) maxX = n.x + w;
      if (n.y + n.height + labelExtra > maxY) maxY = n.y + n.height + labelExtra;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Compute canvas extent for the SizedBox wrapping the Stack.
  (double, double) _contentExtent() {
    final rect = _nodesBoundingRect();
    return (rect.right + 40, rect.bottom + 40);
  }


  /// Walk ancestors of [nodeId] and collect all IDs on the path.
  Set<String> _ancestorPath(String nodeId) {
    final path = <String>{nodeId};
    final parentMap = <String, List<String>>{};
    for (final e in widget.edges) {
      parentMap.putIfAbsent(e.to, () => []).add(e.from);
    }
    void walk(String id) {
      for (final parent in parentMap[id] ?? []) {
        if (path.add(parent)) walk(parent);
      }
    }
    walk(nodeId);
    return path;
  }

  void _onNodeTap(_GraphNode node) {
    setState(() {
      _selectedId = _selectedId == node.id ? null : node.id;
    });
    widget.eventBus.publish(
      widget.channel,
      EventPayload(
        type: 'selection',
        sourceWidgetId: widget.sourceWidgetId,
        data: {
          'nodeId': node.id,
          'label': node.label,
          'iconColor': _effectiveIconColor(node),
          'shape': node.shape,
          'subtitle': node.subtitle,
        },
      ),
    );
  }

  void _onNodeDoubleTap(_GraphNode node) {
    final ch = widget.doubleTapChannel;
    if (ch == null || ch.isEmpty) return;
    widget.eventBus.publish(
      ch,
      EventPayload(
        type: 'doubleTap',
        sourceWidgetId: widget.sourceWidgetId,
        data: {
          'nodeId': node.id,
          'label': node.label,
          'iconColor': node.iconColor,
          'shape': node.shape,
          'subtitle': node.subtitle,
        },
      ),
    );
  }

  /// Effective search query — live channel takes priority over static prop.
  String get _activeSearchQuery =>
      _liveSearchQuery.isNotEmpty ? _liveSearchQuery : widget.searchQuery;

  bool _isSearchMatch(_GraphNode node) {
    final q = _activeSearchQuery;
    if (q.isEmpty) return false;
    return node.label.toLowerCase().contains(q.toLowerCase());
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _transformCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final nodes = widget.nodes;
    final edges = widget.edges;
    final highlightPath = _selectedId != null ? _ancestorPath(_selectedId!) : <String>{};

    final (canvasW, canvasH) = _contentExtent();

    return LayoutBuilder(
      builder: (context, constraints) {
    final viewWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : 800.0;
    final viewHeight = constraints.maxHeight.isFinite ? constraints.maxHeight : 600.0;
    _viewportSize = Size(viewWidth, viewHeight);

    // Auto fit-to-window on first render
    if (!_initialFitApplied && nodes.isNotEmpty) {
      _initialFitApplied = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitToWindow());
    }

    return SizedBox(
      width: viewWidth,
      height: viewHeight,
      child: InteractiveViewer(
      transformationController: _transformCtrl,
      constrained: false,
      minScale: _minScale,
      maxScale: _maxScale,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      child: SizedBox(
        width: canvasW,
        height: canvasH,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Connector layer (behind nodes)
            Positioned.fill(
              child: CustomPaint(
                painter: _GraphConnectorPainter(
                  nodes: nodes,
                  edges: edges,
                  highlightPath: highlightPath,
                  theme: theme,
                ),
              ),
            ),
            // Node layer
            for (final node in nodes)
              Positioned(
                left: node.x,
                top: node.y,
                child: GestureDetector(
                  onTap: () => _onNodeTap(node),
                  onDoubleTap: () => _onNodeDoubleTap(node),
                  child: _buildGraphNode(node, theme, highlightPath),
                ),
              ),
          ],
        ),
      ),
    ),
    );
      },
    );
  }

  /// Running state tokens → show spinner instead of static icon.
  static const _runningIconColors = {'info', 'warning'};

  bool _isRunning(_GraphNode node) => _runningIconColors.contains(node.iconColor);

  /// Returns a spinner or static icon depending on the node's state.
  Widget _nodeIconOrSpinner(_GraphNode node, Color iconColor, IconData icon, double iconSize, SduiTheme theme) {
    if (_isRunning(node)) {
      final spinnerSize = iconSize + 2;
      return SizedBox(
        width: spinnerSize,
        height: spinnerSize,
        child: CircularProgressIndicator(
          strokeWidth: theme.lineWeight.emphasis,
          valueColor: AlwaysStoppedAnimation<Color>(iconColor),
        ),
      );
    }
    return Icon(icon, size: iconSize, color: iconColor);
  }

  Widget _buildGraphNode(_GraphNode node, SduiTheme theme, Set<String> highlight) {
    final isSelected = _selectedId == node.id;
    final isMatch = _isSearchMatch(node);
    // Apply live iconColor override if present
    final effectiveColor = _effectiveIconColor(node);
    final effectiveNode = effectiveColor != node.iconColor
        ? _GraphNode(
            id: node.id, label: node.label,
            x: node.x, y: node.y, width: node.width, height: node.height,
            shape: node.shape, icon: node.icon,
            iconColor: effectiveColor, fill: node.fill,
            borderColor: node.borderColor, subtitle: node.subtitle,
            labelPosition: node.labelPosition,
          )
        : node;
    // Search match → warningContainer tint on fill
    final baseFill = _resolveColor(effectiveNode.fill, theme) ?? theme.colors.surface;
    final fillColor = isMatch
        ? Color.alphaBlend(theme.colors.warningContainer.withAlpha(160), baseFill)
        : baseFill;
    final borderColor = isSelected
        ? theme.colors.primary
        : isMatch
            ? theme.colors.warning
            : (_resolveColor(effectiveNode.borderColor, theme) ?? theme.colors.outline);
    final borderWidth = isSelected ? theme.lineWeight.emphasis : theme.lineWeight.standard;
    final iconColor = _resolveColor(effectiveNode.iconColor, theme) ?? theme.colors.onSurfaceVariant;
    final iconData = _iconMap[effectiveNode.icon] ?? FontAwesomeIcons.circle;

    switch (effectiveNode.shape) {
      case 'circle':
        return _graphCircle(effectiveNode, fillColor, borderColor, borderWidth, iconColor, iconData, theme);
      case 'roundedSquare':
        return _graphRoundedSquare(effectiveNode, fillColor, borderColor, borderWidth, iconColor, iconData, theme);
      case 'hexagon':
        return _graphHexagon(effectiveNode, fillColor, borderColor, borderWidth, iconColor, iconData, theme);
      case 'roundedRect':
      default:
        return _graphRoundedRect(effectiveNode, fillColor, borderColor, borderWidth, iconColor, iconData, theme);
    }
  }

  Widget _graphCircle(_GraphNode node, Color fill, Color border, double bw,
      Color iconColor, IconData icon, SduiTheme theme) {
    final size = node.height > 0 ? node.height : theme.controlHeight.md;
    final iconSize = size > 40 ? theme.iconSize.sm + 2 : theme.iconSize.sm - 2;
    final circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill, shape: BoxShape.circle,
        border: Border.all(color: border, width: bw),
      ),
      child: Center(child: _nodeIconOrSpinner(node, iconColor, icon, iconSize, theme)),
    );
    if (node.labelPosition == 'outside' && node.label.isNotEmpty) {
      final isLarge = size >= 48;
      final labelStyle = theme.textStyles.resolve(isLarge ? 'bodyMedium' : 'bodySmall')?.toTextStyle(
            color: theme.colors.onSurface,
          ) ??
          TextStyle(
            fontSize: isLarge ? theme.textStyles.bodyMedium.fontSize : theme.textStyles.bodySmall.fontSize,
            color: theme.colors.onSurface,
            fontWeight: isLarge ? FontWeight.w600 : FontWeight.w400,
          );
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          circle,
          SizedBox(width: theme.spacing.xs + 2),
          Text(node.label, style: labelStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      );
    }
    // Icon-only circle: show label as tooltip on hover
    if (node.label.isNotEmpty) {
      return Tooltip(message: node.label, child: circle);
    }
    return circle;
  }

  Widget _graphRoundedRect(_GraphNode node, Color fill, Color border, double bw,
      Color iconColor, IconData icon, SduiTheme theme) {
    final w = node.width > 0 ? node.width : null;
    final labelStyle = theme.textStyles.resolve('bodySmall')?.toTextStyle(
          color: theme.colors.onSurface,
        ) ??
        TextStyle(fontSize: theme.textStyles.bodySmall.fontSize, color: theme.colors.onSurface);
    return Container(
      height: theme.controlHeight.md,
      width: w,
      constraints: const BoxConstraints(minWidth: 80, maxWidth: 200),
      padding: EdgeInsets.symmetric(horizontal: theme.spacing.sm - 2),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(theme.radius.md),
        border: Border.all(color: border, width: bw),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _nodeIconOrSpinner(node, iconColor, icon, theme.textStyles.bodyMedium.fontSize ?? 14, theme),
          SizedBox(width: theme.spacing.xs),
          Flexible(
            child: Text(node.label, style: labelStyle,
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _graphRoundedSquare(_GraphNode node, Color fill, Color border, double bw,
      Color iconColor, IconData icon, SduiTheme theme) {
    Widget shape = Container(
      width: theme.controlHeight.md, height: theme.controlHeight.md,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(theme.radius.sm),
        border: Border.all(color: border, width: bw),
      ),
      child: Center(child: _nodeIconOrSpinner(node, iconColor, icon, theme.textStyles.bodyMedium.fontSize ?? 14, theme)),
    );
    // Icon-only shape: show label as tooltip on hover
    if (node.label.isNotEmpty) {
      shape = Tooltip(message: node.label, child: shape);
    }
    return shape;
  }

  Widget _graphHexagon(_GraphNode node, Color fill, Color border, double bw,
      Color iconColor, IconData icon, SduiTheme theme) {
    final showLabel = node.width > 50;
    final labelStyle = theme.textStyles.resolve('bodySmall')?.toTextStyle(
          color: theme.colors.onSurface,
        ) ??
        TextStyle(fontSize: theme.textStyles.bodySmall.fontSize, color: theme.colors.onSurface);
    return SizedBox(
      height: theme.controlHeight.md,
      child: IntrinsicWidth(
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: showLabel ? 60 : theme.controlHeight.md),
          child: CustomPaint(
            painter: _HexagonPainter(fill: fill, border: border, borderWidth: bw),
            child: ClipPath(
              clipper: _HexagonClipper(),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: showLabel ? 14.0 : 4.0),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _nodeIconOrSpinner(node, iconColor, icon, theme.textStyles.bodyMedium.fontSize ?? 14, theme),
                      if (showLabel) ...[
                        SizedBox(width: theme.spacing.xs),
                        Text(node.label, style: labelStyle,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Graph connector painter
// ---------------------------------------------------------------------------

class _GraphConnectorPainter extends CustomPainter {
  final List<_GraphNode> nodes;
  final List<_GraphEdge> edges;
  final Set<String> highlightPath;
  final SduiTheme theme;

  _GraphConnectorPainter({
    required this.nodes,
    required this.edges,
    required this.highlightPath,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final nodeMap = {for (final n in nodes) n.id: n};

    final defaultPaint = Paint()
      ..color = theme.colors.outlineVariant
      ..strokeWidth = theme.lineWeight.vizData
      ..style = PaintingStyle.stroke;

    final highlightPaint = Paint()
      ..color = theme.colors.primary
      ..strokeWidth = theme.lineWeight.vizHighlight
      ..style = PaintingStyle.stroke;

    // Two-pass: default first, highlighted on top
    for (final pass in [false, true]) {
      for (final edge in edges) {
        final from = nodeMap[edge.from];
        final to = nodeMap[edge.to];
        if (from == null || to == null) continue;

        final isHL = highlightPath.contains(from.id) && highlightPath.contains(to.id);
        if (isHL != pass) continue;

        final paint = isHL ? highlightPaint : defaultPaint;
        final exit = _exitPort(from);
        final entry = _entryPort(to);
        if (exit == null || entry == null) continue;

        final path = Path()..moveTo(exit.dx, exit.dy);
        if ((exit.dx - entry.dx).abs() < 2) {
          path.lineTo(entry.dx, entry.dy);
        } else if (entry.dy > exit.dy) {
          final midY = (exit.dy + entry.dy) / 2;
          path.lineTo(exit.dx, midY);
          path.lineTo(entry.dx, midY);
          path.lineTo(entry.dx, entry.dy);
        } else {
          final routeY = exit.dy + 12;
          path.lineTo(exit.dx, routeY);
          path.lineTo(entry.dx, routeY);
          path.lineTo(entry.dx, entry.dy);
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  /// Exit port: bottom-center of the node.
  Offset? _exitPort(_GraphNode n) {
    final (w, h) = _nodeVisualSize(n);
    return Offset(n.x + w / 2, n.y + h);
  }

  /// Entry port: top-center of the node.
  Offset? _entryPort(_GraphNode n) {
    final (w, _) = _nodeVisualSize(n);
    return Offset(n.x + w / 2, n.y);
  }

  /// Returns the visual (width, height) matching what the build methods render.
  (double, double) _nodeVisualSize(_GraphNode n) {
    final ctrlH = theme.controlHeight.md;
    switch (n.shape) {
      case 'circle':
        // _graphCircle uses node.height as diameter
        final d = n.height > 0 ? n.height : ctrlH;
        return (d, d);
      case 'roundedSquare':
        // _graphRoundedSquare uses controlHeight.md for both dimensions
        return (ctrlH, ctrlH);
      case 'hexagon':
        // _graphHexagon: height is controlHeight.md, width is intrinsic
        final w = n.width > 50 ? (n.width > 0 ? n.width : 80.0) : ctrlH;
        return (w, ctrlH);
      case 'roundedRect':
      default:
        // _graphRoundedRect: height is controlHeight.md,
        // width clamped to 80..200 (or node.width if in range)
        final raw = n.width > 0 ? n.width : 100.0;
        final w = raw.clamp(80.0, 200.0);
        return (w, ctrlH);
    }
  }

  @override
  bool shouldRepaint(covariant _GraphConnectorPainter old) =>
      old.highlightPath != highlightPath || old.nodes != nodes;
}

// ---------------------------------------------------------------------------
// Hexagon shape helpers (shared with _buildHexagon in builtin)
// ---------------------------------------------------------------------------

class _HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => _hexPath(size);

  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => false;
}

class _HexagonPainter extends CustomPainter {
  final Color fill, border;
  final double borderWidth;
  _HexagonPainter({required this.fill, required this.border, required this.borderWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final path = _hexPath(size);
    canvas.drawPath(path, Paint()..color = fill..style = PaintingStyle.fill);
    canvas.drawPath(path, Paint()..color = border..strokeWidth = borderWidth..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant _HexagonPainter old) =>
      old.fill != fill || old.border != border;
}

Path _hexPath(Size size) {
  final w = size.width, h = size.height;
  final off = h * 0.25;
  return Path()
    ..moveTo(w / 2, 0)
    ..lineTo(w, off)
    ..lineTo(w, h - off)
    ..lineTo(w / 2, h)
    ..lineTo(0, h - off)
    ..lineTo(0, off)
    ..close();
}

// -- Identicon --

// ── WindowShell — feature window skeleton ──────────────────────────────────

Widget _buildWindowShell(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  final showToolbar = PropConverter.to<bool>(node.props['showToolbar']) ?? true;
  final rawActions = node.props['toolbarActions'] as List<dynamic>? ?? [];
  final theme = ctx.theme;

  return Container(
    color: theme.colors.surface,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showToolbar) ...[
          _WindowToolbar(actions: rawActions, ctx: ctx, parentNodeId: node.id),
          Divider(
            height: theme.lineWeight.subtle,
            thickness: theme.lineWeight.subtle,
            color: theme.colors.outlineVariant.withAlpha(theme.opacity.medium),
          ),
        ],
        Expanded(
          child: children.isEmpty
              ? const SizedBox.shrink()
              : children.length == 1
                  ? children.first
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    ),
        ),
      ],
    ),
  );
}

/// 48px toolbar with styled action buttons matching the window skeleton spec.
///
/// Action descriptors support:
///   - `icon`, `label`, `tooltip` — base appearance
///   - `channel`, `payload` — EventBus action on tap
///   - `isPrimary` — filled (true) or outlined (false) style
///   - `stateKey` — reads boolean from StateManager; when true, swaps to
///     `toggleIcon` / `toggleTooltip` / `toggleLabel`
///   - `enabledStateKey` — reads boolean from StateManager; when false,
///     renders disabled (muted, non-interactive)
class _WindowToolbar extends StatelessWidget {
  final List<dynamic> actions;
  final SduiRenderContext ctx;
  final String parentNodeId;

  const _WindowToolbar({required this.actions, required this.ctx, required this.parentNodeId});

  @override
  Widget build(BuildContext context) {
    final theme = ctx.theme;
    final wt = theme.window;
    // Read StateManager for stateKey/enabledStateKey bindings.
    final manager = StateManagerScope.maybeOf(context);

    // Build action widgets, marking search fields as flexible.
    final built = <Widget>[];
    final flexFlags = <bool>[];
    for (int i = 0; i < actions.length; i++) {
      if (i > 0) {
        built.add(SizedBox(width: wt.toolbarGap));
        flexFlags.add(false);
      }
      final raw = actions[i];
      final isSearch = raw is Map && PropConverter.to<bool>(raw['isSearch']) == true;
      built.add(_buildActionButton(raw, context, manager));
      flexFlags.add(isSearch);
    }

    return Container(
      height: wt.toolbarHeight,
      padding: EdgeInsets.symmetric(horizontal: theme.spacing.sm),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(color: theme.colors.surface),
      child: Row(
        children: [
          for (int i = 0; i < built.length; i++)
            flexFlags[i] ? Flexible(child: built[i]) : built[i],
        ],
      ),
    );
  }

  Widget _buildActionButton(dynamic raw, BuildContext context, StateManager? manager) {
    if (raw is! Map) return const SizedBox.shrink();
    final m = Map<String, dynamic>.from(raw);
    final theme = ctx.theme;

    // Search field — a standard toolbar control like any other.
    if (PropConverter.to<bool>(m['isSearch']) == true) {
      final hint = PropConverter.to<String>(m['hint']) ?? 'Search\u2026';
      final searchChannel = PropConverter.to<String>(m['channel']);
      return _ToolbarSearchField(
        hint: hint,
        width: PropConverter.to<double>(m['width']) ?? 200,
        theme: theme,
        eventBus: ctx.eventBus,
        parentNodeId: parentNodeId,
        searchChannel: searchChannel,
      );
    }

    // WorkflowActionButton — context-sensitive Run/Stop/Reset in the toolbar.
    if (PropConverter.to<bool>(m['isWorkflowAction']) == true) {
      final selChannel = PropConverter.to<String>(m['selectionChannel']) ?? '';
      final workflowId = PropConverter.to<String>(m['workflowId']) ?? '';
      final fakeNode = SduiNode(
        type: 'WorkflowActionButton',
        id: '$parentNodeId-wfaction',
        props: {
          'selectionChannel': selChannel,
          'workflowId': workflowId,
          'runWorkflowChannel': PropConverter.to<String>(m['runWorkflowChannel']) ?? 'workflow.runWorkflow',
          'stopWorkflowChannel': PropConverter.to<String>(m['stopWorkflowChannel']) ?? 'workflow.stopWorkflow',
          'resetWorkflowChannel': PropConverter.to<String>(m['resetWorkflowChannel']) ?? 'workflow.resetWorkflow',
          'runStepChannel': PropConverter.to<String>(m['runStepChannel']) ?? 'workflow.runStep',
          'stopStepChannel': PropConverter.to<String>(m['stopStepChannel']) ?? 'workflow.stopStep',
          'resetStepChannel': PropConverter.to<String>(m['resetStepChannel']) ?? 'workflow.resetStep',
        },
        children: [],
      );
      return _WorkflowActionButton(
        key: ValueKey('wab-$parentNodeId'),
        node: fakeNode,
        ctx: ctx,
      );
    }

    // State-driven toggle: swap icon/tooltip/label when stateKey is true.
    final stateKey = PropConverter.to<String>(m['stateKey']);
    final stateActive = stateKey != null && manager?.get(stateKey) == true;

    final iconName = stateActive
        ? (PropConverter.to<String>(m['toggleIcon']) ?? PropConverter.to<String>(m['icon']))
        : PropConverter.to<String>(m['icon']);
    final label = stateActive
        ? (PropConverter.to<String>(m['toggleLabel']) ?? PropConverter.to<String>(m['label']))
        : PropConverter.to<String>(m['label']);
    final tooltip = stateActive
        ? (PropConverter.to<String>(m['toggleTooltip']) ?? PropConverter.to<String>(m['tooltip']) ?? '')
        : (PropConverter.to<String>(m['tooltip']) ?? '');

    final channel = PropConverter.to<String>(m['channel']) ?? '';
    final payload = m['payload'] as Map<String, dynamic>? ?? {};
    final staticPrimary = PropConverter.to<bool>(m['isPrimary']) ?? false;
    final isGhost = PropConverter.to<bool>(m['isGhost']) ?? false;

    // Dynamic primary: when primaryStateKey is set and truthy, render as primary.
    final primaryStateKey = PropConverter.to<String>(m['primaryStateKey']);
    final primaryState = primaryStateKey != null ? manager?.get(primaryStateKey) : null;
    final isPrimary = staticPrimary ||
        (primaryState != null && primaryState != false && primaryState != '' && primaryState != 0);

    // Enabled state: disabled when enabledStateKey is set and its value is false.
    final enabledStateKey = PropConverter.to<String>(m['enabledStateKey']);
    final enabled = enabledStateKey == null || manager?.get(enabledStateKey) == true;

    void onTap() {
      if (!enabled) return;
      if (channel.isNotEmpty) {
        ctx.eventBus.publish(
          channel,
          EventPayload(type: 'action', sourceWidgetId: parentNodeId, data: payload),
        );
      }
    }

    final iconData = iconName != null ? _iconMap[iconName] : null;

    if (label != null) {
      return _LabeledShellButton(
        icon: iconData,
        label: label,
        isPrimary: isPrimary,
        enabled: enabled,
        onTap: onTap,
        theme: theme,
      );
    }

    // Icon-only button
    return _IconShellButton(
      icon: iconData ?? FontAwesomeIcons.circleQuestion,
      tooltip: tooltip,
      isPrimary: isPrimary,
      isGhost: isGhost,
      enabled: enabled,
      onTap: onTap,
      theme: theme,
    );
  }
}

/// Labeled toolbar button: primary (filled) or secondary (outlined).
class _LabeledShellButton extends StatefulWidget {
  final IconData? icon;
  final String label;
  final bool isPrimary;
  final bool enabled;
  final VoidCallback onTap;
  final SduiTheme theme;

  const _LabeledShellButton({
    this.icon,
    required this.label,
    required this.isPrimary,
    this.enabled = true,
    required this.onTap,
    required this.theme,
  });

  @override
  State<_LabeledShellButton> createState() => _LabeledShellButtonState();
}

class _LabeledShellButtonState extends State<_LabeledShellButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final Color bg;
    final Color fg;
    final Color? border;

    if (!widget.enabled) {
      bg = Colors.transparent;
      fg = t.colors.onSurface.withAlpha(t.opacity.disabled);
      border = null;
    } else if (widget.isPrimary) {
      bg = _hovered
          ? HSLColor.fromColor(t.colors.primary).withLightness(
              (HSLColor.fromColor(t.colors.primary).lightness - 0.08).clamp(0, 1)).toColor()
          : t.colors.primary;
      fg = t.colors.onPrimary;
      border = null;
    } else {
      bg = _hovered ? t.colors.primary.withAlpha(t.opacity.subtle) : Colors.transparent;
      fg = t.colors.primary;
      border = t.colors.primary;
    }

    final wt = t.window;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: t.animation.fast,
          height: wt.toolbarButtonSize,
          padding: EdgeInsets.symmetric(horizontal: t.spacing.md),
          decoration: BoxDecoration(
            color: bg,
            border: border != null ? Border.all(color: border, width: wt.toolbarButtonBorderWidth) : null,
            borderRadius: BorderRadius.circular(wt.toolbarButtonRadius),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: wt.toolbarButtonIconSize, color: fg),
                SizedBox(width: t.spacing.sm),
              ],
              Text(widget.label, style: TextStyle(
                fontFamily: t.fontFamily,
                fontSize: t.textStyles.labelSmall.fontSize,
                fontWeight: FontWeight.w600,
                color: fg,
              )),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon-only toolbar button: secondary outlined style.
class _IconShellButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool isPrimary;
  final bool isGhost;
  final bool enabled;
  final VoidCallback onTap;
  final SduiTheme theme;

  const _IconShellButton({
    required this.icon,
    this.tooltip = '',
    this.isPrimary = false,
    this.isGhost = false,
    this.enabled = true,
    required this.onTap,
    required this.theme,
  });

  @override
  State<_IconShellButton> createState() => _IconShellButtonState();
}

class _IconShellButtonState extends State<_IconShellButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final primary = t.colors.primary;

    final Color bg;
    final Color fg;
    final Border? border;

    if (!widget.enabled) {
      bg = Colors.transparent;
      fg = t.colors.onSurface.withAlpha(t.opacity.disabled);
      border = null;
    } else if (widget.isPrimary) {
      bg = _hovered
          ? HSLColor.fromColor(primary).withLightness(
              (HSLColor.fromColor(primary).lightness - 0.08).clamp(0, 1)).toColor()
          : primary;
      fg = t.colors.onPrimary;
      border = null;
    } else if (widget.isGhost) {
      bg = _hovered ? primary.withAlpha(t.opacity.subtle) : Colors.transparent;
      fg = primary;
      border = null;
    } else {
      bg = _hovered ? primary.withAlpha(t.opacity.subtle) : Colors.transparent;
      fg = primary;
      border = Border.all(color: primary, width: t.window.toolbarButtonBorderWidth);
    }

    final wt = t.window;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: widget.enabled ? (_) => setState(() => _hovered = true) : null,
        onExit: widget.enabled ? (_) => setState(() => _hovered = false) : null,
        child: GestureDetector(
          onTap: widget.enabled ? widget.onTap : null,
          child: AnimatedContainer(
            duration: t.animation.fast,
            width: wt.toolbarButtonSize,
            height: wt.toolbarButtonSize,
            decoration: BoxDecoration(
              color: bg,
              border: border,
              borderRadius: BorderRadius.circular(wt.toolbarButtonRadius),
            ),
            child: Icon(widget.icon, size: wt.toolbarButtonIconSize, color: fg),
          ),
        ),
      ),
    );
  }
}

/// Toolbar search field with accent ring when active and clear button.
class _ToolbarSearchField extends StatefulWidget {
  final String hint;
  final double width;
  final SduiTheme theme;
  final dynamic eventBus;
  final String parentNodeId;
  final String? searchChannel;

  const _ToolbarSearchField({
    required this.hint,
    required this.width,
    required this.theme,
    required this.eventBus,
    required this.parentNodeId,
    this.searchChannel,
  });

  @override
  State<_ToolbarSearchField> createState() => _ToolbarSearchFieldState();
}

class _ToolbarSearchFieldState extends State<_ToolbarSearchField> {
  final TextEditingController _controller = TextEditingController();
  bool _focused = false;

  bool get _hasText => _controller.text.isNotEmpty;

  void _publishSearch(String value) {
    // Publish to the explicit search channel if provided, else use the generic input channel.
    final channel = widget.searchChannel ??
        'input.${widget.parentNodeId}-search.changed';
    widget.eventBus.publish(
      channel,
      EventPayload(
        type: 'input.changed',
        sourceWidgetId: widget.parentNodeId,
        data: {'value': value},
      ),
    );
  }

  void _clear() {
    _controller.clear();
    _publishSearch('');
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final wt = theme.window;
    final btnSize = wt.toolbarButtonSize;
    final isActive = _focused || _hasText;
    final borderColor = isActive ? theme.colors.primary : theme.colors.outline;
    final borderWidth = isActive ? theme.lineWeight.emphasis : theme.lineWeight.subtle;

    return AnimatedContainer(
      duration: theme.animation.fast,
      constraints: BoxConstraints(maxWidth: widget.width, minWidth: btnSize),
      height: btnSize,
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: borderWidth),
        borderRadius: BorderRadius.circular(wt.toolbarButtonRadius),
      ),
      child: Row(
        children: [
          SizedBox(
            width: btnSize,
            child: Icon(FontAwesomeIcons.magnifyingGlass,
                size: wt.toolbarButtonIconSize - 2,
                color: isActive ? theme.colors.primary : theme.colors.onSurfaceMuted),
          ),
          Expanded(
            child: Focus(
              onFocusChange: (hasFocus) => setState(() => _focused = hasFocus),
              child: TextField(
                controller: _controller,
                style: TextStyle(
                    fontFamily: theme.fontFamily,
                    fontSize: theme.textStyles.bodySmall.fontSize),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: TextStyle(
                      fontFamily: theme.fontFamily,
                      fontSize: theme.textStyles.bodySmall.fontSize,
                      color: theme.colors.onSurfaceMuted),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                      vertical: (btnSize - (theme.textStyles.bodySmall.fontSize ?? 12) - 2) / 2),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                onChanged: (value) {
                  _publishSearch(value);
                  setState(() {});
                },
              ),
            ),
          ),
          if (_hasText)
            GestureDetector(
              onTap: _clear,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: SizedBox(
                  width: btnSize,
                  child: Icon(FontAwesomeIcons.xmark,
                      size: wt.toolbarButtonIconSize - 2,
                      color: theme.colors.onSurfaceMuted),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Widget _buildIdenticon(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  final identity = PropConverter.to<String>(node.props['identity']) ?? '';
  final size = PropConverter.to<double>(node.props['size']) ?? 24.0;
  final borderColor = _resolveColor(node.props['borderColor'], ctx.theme);

  final child = ClipOval(
    child: CustomPaint(
      size: Size.square(size),
      painter: _IdenticonPainter(identity),
    ),
  );

  if (borderColor != null) {
    final bw = ctx.theme.lineWeight.standard;
    return Container(
      width: size + bw * 2,
      height: size + bw * 2,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: bw),
      ),
      child: Padding(
        padding: EdgeInsets.all(bw + 1),
        child: child,
      ),
    );
  }

  return SizedBox(width: size, height: size, child: child);
}

class _IdenticonPainter extends CustomPainter {
  final String identity;

  _IdenticonPainter(this.identity);

  @override
  void paint(Canvas canvas, Size size) {
    final bytes = _hashString(identity);

    final fgColor = Color.fromARGB(255, bytes[0], bytes[1], bytes[2]);
    final hsl = HSLColor.fromColor(fgColor);
    final adjusted =
        hsl.lightness > 0.7 ? hsl.withLightness(0.5).toColor() : fgColor;

    final bgPaint = Paint()..color = Colors.white;
    final fgPaint = Paint()..color = adjusted;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final cellW = size.width / 5;
    final cellH = size.height / 5;

    for (int row = 0; row < 5; row++) {
      for (int col = 0; col < 3; col++) {
        final byteIndex = (row * 3 + col) % bytes.length;
        if (bytes[byteIndex] & 1 == 1) {
          canvas.drawRect(
            Rect.fromLTWH(col * cellW, row * cellH, cellW, cellH),
            fgPaint,
          );
          if (col < 2) {
            canvas.drawRect(
              Rect.fromLTWH((4 - col) * cellW, row * cellH, cellW, cellH),
              fgPaint,
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _IdenticonPainter old) =>
      old.identity != identity;

  static Uint8List _hashString(String input) {
    final encoded = utf8.encode(input);
    final result = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      result[i] = (i * 37 + 59) & 0xFF;
    }
    for (int i = 0; i < encoded.length; i++) {
      final idx = i % 16;
      result[idx] = ((result[idx] ^ encoded[i]) * 31 + 17) & 0xFF;
    }
    for (int pass = 0; pass < 3; pass++) {
      for (int i = 0; i < 16; i++) {
        result[i] = ((result[i] ^ result[(i + 1) % 16]) * 37 + 53) & 0xFF;
      }
    }
    return result;
  }
}

// ── New primitives: DangerButton, SubtleButton, Radio, RadioGroup, Badge, Alert, Slider, TabBar ──

Widget _buildDangerButton(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  final text = PropConverter.to<String>(node.props['text']) ?? '';
  final channel = PropConverter.to<String>(node.props['channel']) ?? '';
  final payload = node.props['payload'] as Map<String, dynamic>? ?? {};
  final enabled = PropConverter.to<bool>(node.props['enabled']) ?? true;

  final btn = ctx.theme.button;
  final errorColor = ctx.theme.colors.error;
  return OutlinedButton(
    onPressed: enabled && channel.isNotEmpty
        ? () => ctx.eventBus.publish(
              channel,
              EventPayload(type: 'action', sourceWidgetId: node.id, data: payload),
            )
        : null,
    style: OutlinedButton.styleFrom(
      foregroundColor: errorColor,
      minimumSize: Size(0, ctx.theme.controlHeight.md),
      side: BorderSide(
        color: enabled ? errorColor : errorColor.withAlpha(ctx.theme.opacity.disabled),
        width: btn.outlinedBorderWidth,
      ),
      padding: EdgeInsets.symmetric(horizontal: btn.paddingH, vertical: btn.paddingV),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(btn.borderRadius)),
    ),
    child: Text(text),
  );
}

Widget _buildSubtleButton(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  final text = PropConverter.to<String>(node.props['text']) ?? '';
  final channel = PropConverter.to<String>(node.props['channel']) ?? '';
  final payload = node.props['payload'] as Map<String, dynamic>? ?? {};
  final enabled = PropConverter.to<bool>(node.props['enabled']) ?? true;

  final btn = ctx.theme.button;
  return TextButton(
    onPressed: enabled && channel.isNotEmpty
        ? () => ctx.eventBus.publish(
              channel,
              EventPayload(type: 'action', sourceWidgetId: node.id, data: payload),
            )
        : null,
    style: TextButton.styleFrom(
      foregroundColor: ctx.theme.colors.onSurface,
      backgroundColor: ctx.theme.colors.surfaceContainerLow,
      minimumSize: Size(0, ctx.theme.controlHeight.md),
      padding: EdgeInsets.symmetric(horizontal: btn.paddingH, vertical: btn.paddingV),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(btn.borderRadius)),
    ),
    child: Text(text),
  );
}

Widget _buildRadio(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  return _SduiRadio(node: node, context: ctx);
}

Widget _buildRadioGroup(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  return _SduiRadioGroup(node: node, context: ctx);
}

Widget _buildBadge(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  final text = PropConverter.to<String>(node.props['text']) ?? '';
  final variant = PropConverter.to<String>(node.props['variant']) ?? 'neutral';
  final colors = ctx.theme.colors;

  final (Color bg, Color fg) = switch (variant) {
    'success' => (colors.successContainer, colors.success),
    'info' => (colors.infoContainer, colors.info),
    'warning' => (colors.warningContainer, colors.warning),
    'error' => (colors.errorContainer, colors.error),
    'primary' => (colors.primaryContainer, colors.primary),
    _ => (colors.surfaceContainer, colors.onSurfaceMuted),
  };

  return Container(
    padding: EdgeInsets.symmetric(horizontal: ctx.theme.spacing.sm, vertical: ctx.theme.spacing.xs / 2),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(ctx.theme.radius.full),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: ctx.theme.textStyles.bodySmall.fontSize,
        fontWeight: FontWeight.w500,
        color: fg,
      ),
    ),
  );
}

Widget _buildAlert(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  return _SduiAlert(node: node, context: ctx);
}

Widget _buildSlider(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  return _SduiSlider(node: node, context: ctx);
}

Widget _buildTabBar(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  return _SduiTabBar(node: node, context: ctx);
}

// ── Stateful: Radio ──

class _SduiRadio extends StatefulWidget {
  final SduiNode node;
  final SduiRenderContext context;
  const _SduiRadio({required this.node, required this.context});
  @override
  State<_SduiRadio> createState() => _SduiRadioState();
}

class _SduiRadioState extends State<_SduiRadio> {
  late String? _groupValue;

  @override
  void initState() {
    super.initState();
    _groupValue = PropConverter.to<String>(widget.node.props['groupValue']);
  }

  @override
  void didUpdateWidget(covariant _SduiRadio oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newGroupValue = PropConverter.to<String>(widget.node.props['groupValue']);
    if (newGroupValue != _groupValue) {
      setState(() => _groupValue = newGroupValue);
    }
  }

  void _onChanged(String? value) {
    if (value == null) return;
    setState(() => _groupValue = value);
    final channel = PropConverter.to<String>(widget.node.props['channel'])
        ?? 'input.${widget.node.id}.changed';
    widget.context.eventBus.publish(
      channel,
      EventPayload(
        type: 'input.changed',
        sourceWidgetId: widget.node.id,
        data: {'value': value},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final radioValue = PropConverter.to<String>(widget.node.props['value']) ?? '';
    final enabled = PropConverter.to<bool>(widget.node.props['enabled']) ?? true;
    final label = PropConverter.to<String>(widget.node.props['label']);
    final color = _resolveColor(widget.node.props['color'], widget.context.theme);

    final radio = Radio<String>(
      value: radioValue,
      groupValue: _groupValue,
      onChanged: enabled ? _onChanged : null,
      activeColor: color ?? widget.context.theme.colors.primary,
    );

    if (label != null) {
      return InkWell(
        onTap: enabled ? () => _onChanged(radioValue) : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            radio,
            Text(label, style: TextStyle(
              color: widget.context.theme.colors.onSurface,
              fontSize: widget.context.theme.textStyles.bodyMedium.fontSize,
            )),
          ],
        ),
      );
    }
    return radio;
  }
}

// ── Stateful: RadioGroup ──

class _SduiRadioGroup extends StatefulWidget {
  final SduiNode node;
  final SduiRenderContext context;
  const _SduiRadioGroup({required this.node, required this.context});
  @override
  State<_SduiRadioGroup> createState() => _SduiRadioGroupState();
}

class _SduiRadioGroupState extends State<_SduiRadioGroup> {
  late String? _selectedValue;

  @override
  void initState() {
    super.initState();
    _selectedValue = PropConverter.to<String>(widget.node.props['value']);
  }

  void _onChanged(String? value) {
    if (value == null) return;
    setState(() => _selectedValue = value);
    widget.context.eventBus.publish(
      'input.${widget.node.id}.changed',
      EventPayload(
        type: 'input.changed',
        sourceWidgetId: widget.node.id,
        data: {'value': value},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rawItems = widget.node.props['items'] as List<dynamic>? ?? [];
    final direction = PropConverter.to<String>(widget.node.props['direction']) ?? 'vertical';
    final enabled = PropConverter.to<bool>(widget.node.props['enabled']) ?? true;
    final color = _resolveColor(widget.node.props['color'], widget.context.theme);

    final children = <Widget>[];
    for (final item in rawItems) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final value = PropConverter.to<String>(m['value']) ?? '';
      final label = PropConverter.to<String>(m['label']) ?? value;

      children.add(InkWell(
        onTap: enabled ? () => _onChanged(value) : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Radio<String>(
              value: value,
              groupValue: _selectedValue,
              onChanged: enabled ? _onChanged : null,
              activeColor: color ?? widget.context.theme.colors.primary,
            ),
            Text(label, style: TextStyle(
              color: widget.context.theme.colors.onSurface,
              fontSize: widget.context.theme.textStyles.bodyMedium.fontSize,
            )),
          ],
        ),
      ));
    }

    if (direction == 'horizontal') {
      return Wrap(spacing: widget.context.theme.spacing.md, children: children);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

// ── Stateful: Alert ──

class _SduiAlert extends StatefulWidget {
  final SduiNode node;
  final SduiRenderContext context;
  const _SduiAlert({required this.node, required this.context});
  @override
  State<_SduiAlert> createState() => _SduiAlertState();
}

class _SduiAlertState extends State<_SduiAlert> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final title = PropConverter.to<String>(widget.node.props['title']);
    final message = PropConverter.to<String>(widget.node.props['message']) ?? '';
    final variant = PropConverter.to<String>(widget.node.props['variant']) ?? 'info';
    final dismissible = PropConverter.to<bool>(widget.node.props['dismissible']) ?? false;
    final channel = PropConverter.to<String>(widget.node.props['channel']);
    final colors = widget.context.theme.colors;
    final theme = widget.context.theme;

    final (Color accent, Color iconBg, IconData icon) = switch (variant) {
      'success' => (colors.success, colors.successContainer, FontAwesomeIcons.solidCircleCheck),
      'warning' => (colors.warning, colors.warningContainer, FontAwesomeIcons.triangleExclamation),
      'error' => (colors.error, colors.errorContainer, FontAwesomeIcons.solidCircleXmark),
      _ => (colors.info, colors.infoContainer, FontAwesomeIcons.circleInfo),
    };

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant, width: theme.lineWeight.subtle),
        borderRadius: BorderRadius.circular(theme.radius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left accent border
          Container(
            width: theme.lineWeight.emphasis + 1,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(theme.radius.md),
                bottomLeft: Radius.circular(theme.radius.md),
              ),
            ),
          ),
          // Icon
          Padding(
            padding: EdgeInsets.all(theme.spacing.md),
            child: Container(
              width: theme.window.bodyStateIconSize,
              height: theme.window.bodyStateIconSize,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(theme.radius.full),
              ),
              child: Center(
                child: Icon(icon, size: theme.iconSize.sm, color: accent),
              ),
            ),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: theme.spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null)
                    Padding(
                      padding: EdgeInsets.only(bottom: theme.spacing.xs),
                      child: Text(title, style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: theme.textStyles.bodyMedium.fontSize,
                        color: colors.onSurface,
                      )),
                    ),
                  Text(message, style: TextStyle(
                    fontSize: theme.textStyles.bodyMedium.fontSize,
                    color: colors.onSurfaceVariant,
                  )),
                ],
              ),
            ),
          ),
          // Dismiss button
          if (dismissible)
            Padding(
              padding: EdgeInsets.all(theme.spacing.sm),
              child: IconButton(
                icon: Icon(FontAwesomeIcons.xmark, size: theme.iconSize.sm - 4, color: colors.onSurfaceMuted),
                onPressed: () {
                  setState(() => _dismissed = true);
                  if (channel != null && channel.isNotEmpty) {
                    widget.context.eventBus.publish(
                      channel,
                      EventPayload(type: 'dismiss', sourceWidgetId: widget.node.id, data: {}),
                    );
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ── Stateful: Slider ──

class _SduiSlider extends StatefulWidget {
  final SduiNode node;
  final SduiRenderContext context;
  const _SduiSlider({required this.node, required this.context});
  @override
  State<_SduiSlider> createState() => _SduiSliderState();
}

class _SduiSliderState extends State<_SduiSlider> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = PropConverter.to<double>(widget.node.props['value']) ?? 0;
  }

  void _onChanged(double value) {
    setState(() => _value = value);
    widget.context.eventBus.publish(
      'input.${widget.node.id}.changed',
      EventPayload(
        type: 'input.changed',
        sourceWidgetId: widget.node.id,
        data: {'value': value},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final min = PropConverter.to<double>(widget.node.props['min']) ?? 0;
    final max = PropConverter.to<double>(widget.node.props['max']) ?? 1;
    final divisions = PropConverter.to<int>(widget.node.props['divisions']);
    final label = PropConverter.to<String>(widget.node.props['label']);
    final enabled = PropConverter.to<bool>(widget.node.props['enabled']) ?? true;
    final color = _resolveColor(widget.node.props['color'], widget.context.theme);

    Widget slider = SliderTheme(
      data: SliderThemeData(
        activeTrackColor: color ?? widget.context.theme.colors.primary,
        inactiveTrackColor: widget.context.theme.colors.surfaceContainerHigh,
        thumbColor: color ?? widget.context.theme.colors.primary,
        trackHeight: widget.context.theme.lineWeight.standard,
      ),
      child: Slider(
        value: _value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        onChanged: enabled ? _onChanged : null,
      ),
    );

    if (label != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: widget.context.theme.spacing.xs),
            child: Text(label, style: TextStyle(
              fontSize: widget.context.theme.textStyles.labelSmall.fontSize,
              fontWeight: FontWeight.w500,
              color: widget.context.theme.colors.onSurfaceVariant,
            )),
          ),
          slider,
        ],
      );
    }
    return slider;
  }
}

// ── Stateful: TabBar ──

class _SduiTabBar extends StatefulWidget {
  final SduiNode node;
  final SduiRenderContext context;
  const _SduiTabBar({required this.node, required this.context});
  @override
  State<_SduiTabBar> createState() => _SduiTabBarState();
}

class _SduiTabBarState extends State<_SduiTabBar> with SingleTickerProviderStateMixin {
  late TabController _controller;
  late List<Map<String, dynamic>> _tabs;

  @override
  void initState() {
    super.initState();
    final rawTabs = widget.node.props['tabs'] as List<dynamic>? ?? [];
    _tabs = rawTabs.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    final selected = PropConverter.to<int>(widget.node.props['selected']) ?? 0;
    _controller = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: selected.clamp(0, _tabs.isEmpty ? 0 : _tabs.length - 1),
    );
    _controller.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_controller.indexIsChanging) return;
    final tabLabel = _tabs.isNotEmpty ? (PropConverter.to<String>(_tabs[_controller.index]['label']) ?? '') : '';
    widget.context.eventBus.publish(
      'input.${widget.node.id}.changed',
      EventPayload(
        type: 'input.changed',
        sourceWidgetId: widget.node.id,
        data: {'value': _controller.index, 'tab': tabLabel},
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onTabChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _resolveColor(widget.node.props['color'], widget.context.theme)
        ?? widget.context.theme.colors.primary;
    final tokens = widget.context.theme.internalTab;

    return SizedBox(
      height: tokens.height,
      child: TabBar(
        controller: _controller,
        isScrollable: true,
        indicatorColor: color,
        indicatorWeight: tokens.activeBorderWidth,
        labelColor: color,
        unselectedLabelColor: widget.context.theme.colors.onSurfaceMuted,
        labelStyle: TextStyle(
          fontSize: tokens.fontSize,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: tokens.fontSize,
          fontWeight: FontWeight.w400,
        ),
        tabAlignment: TabAlignment.start,
        dividerHeight: widget.context.theme.lineWeight.subtle,
        dividerColor: widget.context.theme.colors.outlineVariant,
        tabs: _tabs.map((tab) {
          final tabLabel = PropConverter.to<String>(tab['label']) ?? '';
          final iconName = PropConverter.to<String>(tab['icon']);
          if (iconName != null) {
            final iconData = _iconMap[iconName] ?? FontAwesomeIcons.circleQuestion;
            return Tab(
              height: tokens.height,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(iconData, size: tokens.iconSize),
                  SizedBox(width: widget.context.theme.spacing.xs),
                  Text(tabLabel),
                ],
              ),
            );
          }
          return Tab(height: tokens.height, text: tabLabel);
        }).toList(),
      ),
    );
  }
}
