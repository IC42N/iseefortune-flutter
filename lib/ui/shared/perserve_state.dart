import 'package:flutter/widgets.dart';

class PreserveState extends StatefulWidget {
  final Widget child;

  const PreserveState({super.key, required this.child});

  @override
  State<PreserveState> createState() => _PreserveStateState();
}

class _PreserveStateState extends State<PreserveState> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
