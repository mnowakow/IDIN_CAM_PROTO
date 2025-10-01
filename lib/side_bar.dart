import 'package:flutter/material.dart';
import 'package:idin_cam_prototype/filtered_view.dart';
import 'package:idin_cam_prototype/miniview.dart';
import 'package:idin_cam_prototype/scroll_notifier.dart';
import 'package:idin_cam_prototype/sidebar_notifier.dart';

enum SidebarPosition { top, bottom, left, right }

class ExpandableSidebar extends StatefulWidget {
  final SidebarPosition position;
  final ScrollNotifier scrollNotifier;

  const ExpandableSidebar({
    super.key,
    required this.position,
    required this.scrollNotifier,
  });

  @override
  State<ExpandableSidebar> createState() => _ExpandableSidebarState();
}

class _ExpandableSidebarState extends State<ExpandableSidebar> {
  bool expanded = false;
  SideBarWidget selectedWidget = SideBarWidget.miniView;

  @override
  Widget build(BuildContext context) {
    Widget sidebarContent = Container(
      decoration: BoxDecoration(
        color: Colors.amber,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(2, 2)),
        ],
      ),
      width:
          widget.position == SidebarPosition.left ||
                  widget.position == SidebarPosition.right
              ? (expanded ? 200 : 70)
              : double.infinity,
      height:
          widget.position == SidebarPosition.top ||
                  widget.position == SidebarPosition.bottom
              ? (expanded ? 200 : 40)
              : double.infinity,
      child: Row(
        textDirection:
            widget.position == SidebarPosition.right
                ? TextDirection.rtl
                : TextDirection.ltr,
        children: [
          // Main sidebar column
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 40,
                  icon: Icon(Icons.auto_awesome_mosaic, size: 40),
                  onPressed:
                      () => setState(() {
                        if (selectedWidget == SideBarWidget.miniView) {
                          expanded = !expanded;
                        }
                        selectedWidget = SideBarWidget.miniView;
                        SidebarNotifier.instance.openSidebar = selectedWidget;
                      }),
                ),
                // SizedBox(height: 24),
                // IconButton(
                //   iconSize: 40,
                //   icon: Icon(Icons.bookmark, size: 40),
                //   onPressed:
                //       () => setState(() {
                //         if (selectedWidget == SideBarWidget.bookmarks) {
                //           expanded = !expanded;
                //         }
                //         selectedWidget = SideBarWidget.bookmarks;
                //         SidebarNotifier.instance.openSidebar = selectedWidget;
                //       }),
                // ),
                SizedBox(height: 24),
                IconButton(
                  iconSize: 40,
                  icon: Container(
                    decoration: BoxDecoration(
                      color:
                          SidebarNotifier.instance.openSidebar ==
                                  SideBarWidget.colorPalette
                              ? Colors.green.shade400
                              : null,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.color_lens, size: 40),
                  ),
                  onPressed:
                      () => setState(() {
                        expanded = false;
                        if (selectedWidget == SideBarWidget.colorPalette) {
                          selectedWidget = SideBarWidget.none;
                          // expanded = false;
                        } else {
                          // expanded = true;
                          selectedWidget = SideBarWidget.colorPalette;
                        }
                        SidebarNotifier.instance.openSidebar = selectedWidget;
                      }),
                ),
                SizedBox(height: 24),
                IconButton(
                  iconSize: 40,
                  icon: Container(
                    decoration: BoxDecoration(
                      color:
                          SidebarNotifier.instance.openSidebar ==
                                  SideBarWidget.camera
                              ? Colors.green.shade400
                              : null,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.camera_outlined, size: 40),
                  ),
                  onPressed:
                      () => setState(() {
                        //expanded = false;
                        selectedWidget = SideBarWidget.camera;
                        if (SidebarNotifier.instance.openSidebar !=
                            SideBarWidget.camera) {
                          SidebarNotifier.instance.openSidebar = selectedWidget;
                        } else {
                          SidebarNotifier.instance.openSidebar =
                              SideBarWidget.none;
                        }
                      }),
                ),
                SizedBox(height: 24),
                IconButton(
                  iconSize: 40,
                  icon: Icon(Icons.delete_forever, size: 40),
                  onPressed: () {},
                  onLongPress: () {
                    print("Trash Icon Long Pressed");
                    setState(() {
                      //expanded = false;
                      selectedWidget = SideBarWidget.trash;
                      if (SidebarNotifier.instance.openSidebar !=
                          SideBarWidget.trash) {
                        SidebarNotifier.instance.openSidebar = selectedWidget;
                      } else {
                        SidebarNotifier.instance.openSidebar =
                            SideBarWidget.none;
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          // Expanded content column
          if (expanded)
            Expanded(
              child:
                  selectedWidget == SideBarWidget.miniView
                      ? MiniView(
                        pdfAssetPath: "assets/pdfs/lafiamma.pdf",
                        scrollNotifier: widget.scrollNotifier,
                      )
                      : selectedWidget == SideBarWidget.bookmarks
                      ? FilteredView(
                        isMiniView: true,
                        scrollNotifier: widget.scrollNotifier,
                      )
                      : selectedWidget == SideBarWidget.colorPalette
                      ? Container() //ColorPaletteView()
                      : Container(),
            ),
        ],
      ),
    );

    switch (widget.position) {
      case SidebarPosition.left:
        return Align(alignment: Alignment.centerLeft, child: sidebarContent);
      case SidebarPosition.right:
        return Align(alignment: Alignment.centerRight, child: sidebarContent);
      case SidebarPosition.top:
        return Align(alignment: Alignment.topCenter, child: sidebarContent);
      case SidebarPosition.bottom:
        return Align(alignment: Alignment.bottomCenter, child: sidebarContent);
    }
  }
}
