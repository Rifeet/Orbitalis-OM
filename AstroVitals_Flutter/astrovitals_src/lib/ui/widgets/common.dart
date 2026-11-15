/// Shared building blocks: panels, cards, section headers, buttons, source
/// badges, accordions, list rows - all styled after the reference design.
library;

import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../core/engine/engine.dart' show ageText;
import 'status_icon.dart';

/// rounded surface panel (the design's .panel - soft redesign pass:
/// border 0, radius 18, background --surf, inset highlight + drop shadow)
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(18)});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: p.surf,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.white.withValues(alpha: 0.05), blurRadius: 0,
              spreadRadius: -1, offset: const Offset(0, 1)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 30, offset: const Offset(0, 10)),
        ],
      ),
      child: child,
    );
  }
}

/// panel header: h2 + optional small
class PanelHead extends StatelessWidget {
  final String title;
  final String? small;
  const PanelHead(this.title, {super.key, this.small});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(color: p.holo, shape: BoxShape.circle),
          ),
          Expanded(
            child: Text(title,
                style: AVText.displayStyle(19, w: FontWeight.w600, color: p.fg)),
          ),
          if (small != null)
            Text(small!, style: AVText.bodyStyle(13.5, color: p.muted)),
        ],
      ),
    );
  }
}

/// section group header (.grp)
class GroupHead extends StatelessWidget {
  final String title;
  final String small;
  final Widget? trailing;
  final bool done;
  const GroupHead(this.title, {super.key, required this.small, this.trailing, this.done = false});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 26, 4, 12),
      child: Row(
        children: [
          if (done) ...[StatusIcon(0, size: 18), const SizedBox(width: 8)],
          Flexible(
            child: Text(title,
                style: AVText.displayStyle(18, w: FontWeight.w600, color: p.fg)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(small, style: AVText.bodyStyle(14, color: p.muted)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// primary / ghost / small buttons (.btn, .ghost, .sm) + EVA target sizes
/// Sized by symmetric padding (never `alignment`): stays content-sized inside
/// Wrap / Column loose constraints, matching the reference pills. [expand]
/// stretches to the parent width (used by the auth forms).
class AVButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool ghost;
  final bool small;
  final bool expand;
  const AVButton(this.label, {super.key, this.onPressed, this.ghost = false, this.small = false, this.expand = false});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    final enabled = onPressed != null;
    final labelStyle = AVText.bodyStyle(small ? 14 : 15,
        w: FontWeight.w600, color: ghost ? p.fg : const Color(0xFF06121D));
    // symmetric padding gives the exact 46/38/58 px pill heights and keeps the
    // button content-sized in every constraint context (Wrap / Row / Column)
    double vPad = small ? 8 : 11;
    double hPad = small ? 16 : 22;
    if (p.evaTargets) vPad = 17;
    Widget btn = Material(
      color: ghost ? p.surf2 : p.blue,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          child: Row(
            // expand (auth forms): fill the tight parent width, centre the label
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: expand ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [Text(label, style: labelStyle)],
          ),
        ),
      ),
    );
    if (expand) {
      btn = SizedBox(width: double.infinity, child: btn);
    }
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Semantics(button: true, child: btn),
    );
  }
}

/// small underlined link button (.lnk)
class AVLink extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const AVLink(this.label, {super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 6),
      ),
      child: Text(label,
          style: AVText.bodyStyle(14, color: p.muted)
              .copyWith(decoration: TextDecoration.underline)),
    );
  }
}

/// segmented pills (.seg)
class AVSegment extends StatelessWidget {
  final List<(String, String)> options; // (value, label)
  final String value;
  final ValueChanged<String> onChanged;
  const AVSegment({super.key, required this.options, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: p.surf2,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((o) {
          final sel = o.$1 == value;
          return Material(
            color: sel ? p.blue : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onChanged(o.$1),
              child: Container(
                // 9px vertical padding -> the design's 40px segment height
                padding: EdgeInsets.symmetric(
                    horizontal: 14, vertical: p.evaTargets ? 15 : 9),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(o.$2,
                      style: AVText.bodyStyle(14,
                          w: FontWeight.w500,
                          color: sel ? const Color(0xFF06121D) : p.fg)),
                ]),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// select dropdown styled like the design's select
/// ([minWidth] mirrors .demobar select{min-width:190px})
class AVSelect<T> extends StatelessWidget {
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T?> onChanged;
  final String? label;
  final double minWidth;
  const AVSelect({super.key, required this.value, required this.items, required this.onChanged, this.label, this.minWidth = 0});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    final h = p.evaTargets ? 58.0 : 44.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(label!,
                style: AVText.bodyStyle(12, w: FontWeight.w500, color: p.muted)),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: p.surf2,
            borderRadius: BorderRadius.circular(12),
          ),
          constraints: BoxConstraints(minHeight: h, minWidth: minWidth),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isDense: true,
              dropdownColor: p.panelSolid,
              borderRadius: BorderRadius.circular(12),
              style: AVText.bodyStyle(15, color: p.fg),
              icon: Icon(Icons.expand_more, size: 18, color: p.muted),
              items: items
                  .map((i) => DropdownMenuItem<T>(
                        value: i.$1,
                        child: Text(i.$2),
                      ))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

/// source badge row (.src): device name + age + partial/direct tag
class SourceBadge extends StatelessWidget {
  final String device;
  final int? ts;
  final String? srcNote;
  final String? tag; // 'Partial source' | 'Direct source' | 'Crew entry'
  const SourceBadge({super.key, this.device = '', this.ts, this.srcNote, this.tag});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    // subscribe so the age text stays fresh
    AVStore.of(context);
    final now = DateTime.now().millisecondsSinceEpoch;
    final children = <Widget>[];
    if (tag != null) {
      children.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: p.surf2,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(tag!, style: AVText.bodyStyle(12, color: p.muted)),
      ));
    }
    if (srcNote != null) children.add(Text(srcNote!, style: AVText.bodyStyle(13, color: p.muted)));
    if (device.isNotEmpty) children.add(Text(device, style: AVText.bodyStyle(13, color: p.muted)));
    if (ts != null) {
      children.add(Text(ageText(ts!, now), style: AVText.bodyStyle(12.5, color: p.muted)));
    }
    return Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: children);
  }
}

/// details accordion (summary + body)
class Accordion extends StatelessWidget {
  final String summary;
  final List<Widget> children;
  final bool initiallyOpen;
  const Accordion(this.summary, {super.key, required this.children, this.initiallyOpen = false});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        initiallyExpanded: initiallyOpen,
        iconColor: p.blue,
        collapsedIconColor: p.blue,
        title: Text(summary, style: AVText.bodyStyle(14, color: p.blue)),
        children: children,
      ),
    );
  }
}

/// small labelled input wrapper
class FieldLabel extends StatelessWidget {
  final String label;
  final Widget child;
  const FieldLabel({super.key, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AVText.bodyStyle(11, w: FontWeight.w500, color: p.muted)),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

/// text field styled after the design inputs
/// ([obscure] + [suffix] used by the auth forms; [onSubmitted] for enter key)
class AVTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final bool error;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int? maxLines;
  final int? maxLength;
  final bool obscure;
  final Widget? suffix;
  const AVTextField({
    super.key,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.error = false,
    this.onChanged,
    this.onSubmitted,
    this.maxLines = 1,
    this.maxLength,
    this.obscure = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      maxLines: maxLines,
      maxLength: maxLength,
      obscureText: obscure,
      style: AVText.bodyStyle(15, color: p.fg),
      cursorColor: p.blue,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AVText.bodyStyle(15, color: p.muted.withValues(alpha: 0.7)),
        counterText: '',
        filled: true,
        fillColor: p.mixColors(Colors.black, 0.3),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: error ? p.tierT(4) : Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: error ? p.tierT(4) : p.blue),
        ),
        suffixIcon: suffix,
        suffixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      ),
    );
  }
}

/// inline error text (.err)
class ErrorText extends StatelessWidget {
  final String? error;
  const ErrorText(this.error, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    if (error == null || error!.isEmpty) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(error!, style: AVText.bodyStyle(12, color: p.tierT(4))),
    );
  }
}

/// simple key-value tiles (.kv)
class KvTile extends StatelessWidget {
  final String value;
  final String label;
  const KvTile(this.value, this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    return Container(
      padding: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: p.line, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AVText.num(22, color: p.fg)),
          Text(label, style: AVText.bodyStyle(11, color: p.muted)),
        ],
      ),
    );
  }
}

/// progress meter (.meter / .prog)
class AVMeter extends StatelessWidget {
  final double pct; // 0..100
  final int? level;
  final double height;
  const AVMeter(this.pct, {super.key, this.level, this.height = 8});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    final c = level != null ? p.tierC(level!) : p.blue;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Stack(
        children: [
          Container(height: height, color: Colors.white.withValues(alpha: 0.1)),
          FractionallySizedBox(
            widthFactor: (pct / 100).clamp(0.0, 1.0),
            child: Container(height: height, color: c),
          ),
        ],
      ),
    );
  }
}

/// list row (.list div)
class ListRow extends StatelessWidget {
  final Widget left;
  final Widget? right;
  const ListRow(this.left, {super.key, this.right});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.lineSoft)),
      ),
      child: Row(
        children: [
          Expanded(child: left),
          if (right != null) right!,
        ],
      ),
    );
  }
}

/// tag for 'Example' journal entries
class TagEx extends StatelessWidget {
  const TagEx({super.key});

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: p.lineSoft),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('Example', style: AVText.bodyStyle(10, w: FontWeight.w600, color: p.muted)),
    );
  }
}
