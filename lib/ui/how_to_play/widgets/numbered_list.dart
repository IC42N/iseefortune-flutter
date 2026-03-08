import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/how_to_play/widgets/maybe_link_text.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class ListItem {
  const ListItem({required this.leading, required this.text, this.link});
  final String leading;
  final String text;
  final String? link;
}

class NumberedList extends StatelessWidget {
  const NumberedList({super.key, required this.items});
  final List<ListItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.map((it) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacityCompat(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacityCompat(0.10)),
                ),
                child: Text(
                  it.leading,
                  style: TextStyle(
                    color: Colors.white.withOpacityCompat(0.82),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MaybeLinkText(text: it.text, url: it.link),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
