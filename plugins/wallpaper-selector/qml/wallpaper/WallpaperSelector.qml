import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Controls
import QtQuick.Shapes
import qs.utils
import qs.services.api
import qs.components
import qs.components.controls
import qs.components.images
import Caelestia
import Caelestia.Config as ShellConfig
import Caelestia.Models
import qs.services
import ".."
import ".." as PluginStyle


PanelWindow {
  id: appWallpaper

  
  
  property var colors
  property bool showing: false
  property bool isMainScreen: true
  
  property var wallpaperResults: ScriptModel {
    values: {
      var _dummy = CaelestiaApi.visuals.wallpaper.list;
      return CaelestiaApi.visuals.wallpaper.query(searchInput.text);
    }
  }

  
  onShowingChanged: {
    if (showing) {
      searchInput.text = ""
      
      cardShowTimer.restart()
      
    } else {
      cardVisible = false
      searchInput.text = ""
      Qt.callLater(function() { gc() })
    }
  }

  Timer {
    id: cardShowTimer
    interval: 50
    onTriggered: appWallpaper.cardVisible = true
  }

  Timer {
    id: focusTimer
    interval: 50
    onTriggered: sliceListView.forceActiveFocus()
  }

  
  property int sliceWidth: Config.sliceWidth
  
  Shortcut {
    sequences: ["Tab", "Right", "Down", "D", "S"]
    onActivated: appWallpaper.cycleNext()
    enabled: appWallpaper.cardVisible && appWallpaper.isMainScreen && !searchInput.activeFocus
  }

  Shortcut {
    sequences: ["Shift+Tab", "Left", "Up", "A", "W"]
    onActivated: appWallpaper.cyclePrev()
    enabled: appWallpaper.cardVisible && appWallpaper.isMainScreen && !searchInput.activeFocus
  }

  property int expandedWidth: Config.expandedWidth
  property int sliceHeight: Config.sliceHeight
  property int skewOffset: Config.skewOffset
  property int sliceSpacing: Config.sliceSpacing
  property int visibleCount: Config.visibleCount


  property bool isSliceMode:  Config.displayMode === "slice"
  property bool isHexMode:    Config.displayMode === "hex"
  property bool isGridMode:   Config.displayMode === "wall"

  property string _lastMode: Config.displayMode
  Connections {
    target: Config
    function onDisplayModeChanged() {
      if (Config.displayMode !== appWallpaper._lastMode) {
        appWallpaper._lastMode = Config.displayMode
        Qt.callLater(function() { gc() })
      }
    }
  }

  
  readonly property int _hexCellW: Config.hexRadius * 2
  readonly property int _hexCellH: Math.ceil(Config.hexRadius * 1.73205)
  readonly property int hexGridWidth: _hexCellW * Config.hexCols + Config.hexRadius
  readonly property int hexGridHeight: _hexCellH * Config.hexRows + (Config.hexRows > 1 ? _hexCellH * 0.5 : 0)

  
  readonly property int _gridCellGap: 8
  readonly property int _gridTotalW: Config.gridColumns * (Config.gridThumbWidth + _gridCellGap)
  readonly property int _gridTotalH: Config.gridRows * (Config.gridThumbHeight + _gridCellGap)

  
  property int topBarHeight: 90
  property int bottomBarHeight: 90
  property int cardWidth: {
    if (isHexMode)    return hexGridWidth + 60
    if (isGridMode)   return _gridTotalW + 40
    return 1600
  }
  property int cardHeight: {
    if (isHexMode)    return hexGridHeight + topBarHeight + bottomBarHeight
    if (isGridMode)   return _gridTotalH + topBarHeight + bottomBarHeight
    return sliceHeight + topBarHeight + bottomBarHeight
  }

  property bool cardVisible: false

  property int lastContentX: 0
  property int lastIndex: 0

  function resetScroll() {
    lastContentX = 0
    lastIndex = 0
    sliceListView.currentIndex = 0
    if (appWallpaper.wallpaperResults.count > 0)
      sliceListView.positionViewAtIndex(0, ListView.Beginning)
  }


  Timer {
    id: interactionBlockerTimer
    interval: 300
  }
  property bool blockHover: interactionBlockerTimer.running

  function cycleNext(step) {
      if (!appWallpaper.wallpaperResults || appWallpaper.wallpaperResults.count === 0) return
      interactionBlockerTimer.restart()
      var s = step || 1
      var nextIdx = 0
      var count = appWallpaper.wallpaperResults.count
      if (appWallpaper.isSliceMode) {
        nextIdx = (sliceListView.currentIndex + s) % count
        if (nextIdx < 0) nextIdx += count
        sliceListView.currentIndex = nextIdx
        sliceListView.positionViewAtIndex(nextIdx, ListView.Center)
      } else if (appWallpaper.isHexMode) {
        nextIdx = (hexListView.currentIndex + s) % count
        if (nextIdx < 0) nextIdx += count
        hexListView.currentIndex = nextIdx
        hexListView._selectedCol = nextIdx
        hexListView.positionViewAtIndex(nextIdx, ListView.Center)
      } else if (appWallpaper.isGridMode) {
        nextIdx = (thumbGridView.currentIndex + s) % count
        if (nextIdx < 0) nextIdx += count
        thumbGridView.currentIndex = nextIdx
        thumbGridView._ensureVisible(nextIdx)
      }
      var wall = appWallpaper.wallpaperResults.get(nextIdx)
      if (wall) {
          CaelestiaApi.visuals.wallpaper.setWallpaper(wall.path)
      }
  }

  function cyclePrev(step) {
      if (!appWallpaper.wallpaperResults || appWallpaper.wallpaperResults.count === 0) return
      interactionBlockerTimer.restart()
      var s = step || 1
      var nextIdx = 0
      var count = appWallpaper.wallpaperResults.count
      if (appWallpaper.isSliceMode) {
        nextIdx = (sliceListView.currentIndex - s) % count
        if (nextIdx < 0) nextIdx += count
        sliceListView.currentIndex = nextIdx
        sliceListView.positionViewAtIndex(nextIdx, ListView.Center)
      } else if (appWallpaper.isHexMode) {
        nextIdx = (hexListView.currentIndex - s) % count
        if (nextIdx < 0) nextIdx += count
        hexListView.currentIndex = nextIdx
        hexListView._selectedCol = nextIdx
        hexListView.positionViewAtIndex(nextIdx, ListView.Center)
      } else if (appWallpaper.isGridMode) {
        nextIdx = (thumbGridView.currentIndex - s) % count
        if (nextIdx < 0) nextIdx += count
        thumbGridView.currentIndex = nextIdx
        thumbGridView._ensureVisible(nextIdx)
      }
      var wall = appWallpaper.wallpaperResults.get(nextIdx)
      if (wall) {
          CaelestiaApi.visuals.wallpaper.setWallpaper(wall.path)
      }
  }

  
  property bool realShowing: appWallpaper.showing
  property real tintOpacity: realShowing ? 1.0 : 0.0
  Behavior on tintOpacity { NumberAnimation { duration: 300 } }

  visible: appWallpaper.showing || tintOpacity > 0
  color: "transparent"

  anchors { top: true; bottom: true; left: true; right: true }

  WlrLayershell.namespace: "wallpaper-selector"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: appWallpaper.showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  exclusionMode: ExclusionMode.Ignore

  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.5)
    opacity: appWallpaper.tintOpacity
  }

  MouseArea {
    anchors.fill: parent
    onClicked: appWallpaper.showing = false
  }

  Item {
      id: cardContainer

      width: appWallpaper.cardWidth
      height: appWallpaper.cardHeight
      anchors.centerIn: parent
      visible: appWallpaper.showing && appWallpaper.cardVisible && appWallpaper.isMainScreen

      property bool animateIn: appWallpaper.cardVisible

      onAnimateInChanged: {
        fadeInAnim.stop()
        if (animateIn) {
          opacity = 0
          fadeInAnim.start()
          focusTimer.restart()
        }
      }

      NumberAnimation {
        id: fadeInAnim
        target: cardContainer
        property: "opacity"
        from: 0; to: 1
        duration: 400
        easing.type: Easing.OutCubic
      }

      MouseArea {
        anchors.fill: parent
        onClicked: {}
      }

      Item {
        id: backgroundRect
        anchors.fill: parent

          StyledRect {
              id: topSearchBar
              anchors.top: parent.top
              anchors.topMargin: 25
              anchors.horizontalCenter: parent.horizontalCenter
              z: 11

              color: Qt.rgba(appWallpaper.colors.surface.r, appWallpaper.colors.surface.g, appWallpaper.colors.surface.b, 0.95)
              border.width: 1
              border.color: appWallpaper.colors.outline
              radius: ShellConfig.Tokens.rounding.full
              implicitWidth: searchIcon.implicitWidth + searchInput.width + ShellConfig.Tokens.padding.medium * 2 + ShellConfig.Tokens.spacing.small
              implicitHeight: searchInput.implicitHeight

              MaterialIcon {
                  id: searchIcon
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.left: parent.left
                  anchors.leftMargin: ShellConfig.Tokens.padding.medium
                  text: "search"
                  color: appWallpaper.colors.surfaceText
              }

              StyledTextField {
                  id: searchInput
                  anchors.left: searchIcon.right
                  anchors.leftMargin: ShellConfig.Tokens.spacing.small
                  anchors.verticalCenter: parent.verticalCenter
                  width: 250
                  placeholderText: qsTr("Search wallpapers...")
                  color: appWallpaper.colors.surfaceText
                  placeholderTextColor: Qt.rgba(appWallpaper.colors.surfaceText.r, appWallpaper.colors.surfaceText.g, appWallpaper.colors.surfaceText.b, 0.6)
                  
                  topPadding: ShellConfig.Tokens.padding.medium
                  bottomPadding: ShellConfig.Tokens.padding.medium

                  onTextChanged: CaelestiaApi.visuals.wallpaper.searchText = text
                  onAccepted: {
                    if (sliceListView.currentIndex >= 0 && sliceListView.currentIndex < appWallpaper.wallpaperResults.count) {
                      var wall = appWallpaper.wallpaperResults.get(sliceListView.currentIndex)
                      CaelestiaApi.visuals.wallpaper.setWallpaper(wall.path)
                      appWallpaper.showing = false
                    }
                  }
                  Keys.onEscapePressed: appWallpaper.showing = false
              }
          }




        Rectangle {
          anchors.fill: parent
          z: -1
          color: Qt.rgba(appWallpaper.colors.surfaceContainer.r,
                         appWallpaper.colors.surfaceContainer.g,
                         appWallpaper.colors.surfaceContainer.b, 0.95)
          radius: 20
          clip: true
          opacity: 0 // hidden per user request
        }
      }
    }


    ListView {
      id: sliceListView
      visible: appWallpaper.cardVisible && appWallpaper.isSliceMode
      anchors.top: cardContainer.top
      anchors.topMargin: appWallpaper.topBarHeight
      anchors.bottom: cardContainer.bottom
      anchors.bottomMargin: appWallpaper.bottomBarHeight
      anchors.horizontalCenter: parent.horizontalCenter
      property int visibleCount: appWallpaper.visibleCount
      width: appWallpaper.expandedWidth + (visibleCount - 1) * (appWallpaper.sliceWidth + appWallpaper.sliceSpacing)
      Behavior on width { NumberAnimation { duration: Style.animExpand; easing.type: Easing.OutCubic } }

      orientation: ListView.Horizontal
      model: appWallpaper.cardVisible && appWallpaper.isSliceMode ? appWallpaper.wallpaperResults : null
      clip: false
      spacing: appWallpaper.sliceSpacing
      keyNavigationEnabled: false

      flickDeceleration: 1500
      maximumFlickVelocity: 3000
      boundsBehavior: Flickable.StopAtBounds
      cacheBuffer: appWallpaper.expandedWidth

      property bool keyboardNavActive: false
      property real lastMouseX: -1
      property real lastMouseY: -1

      highlightFollowsCurrentItem: true
      highlightMoveDuration: Style.animExpand
      highlight: Item {}
      preferredHighlightBegin: (width - appWallpaper.expandedWidth) / 2
      preferredHighlightEnd: (width + appWallpaper.expandedWidth) / 2
      highlightRangeMode: ListView.StrictlyEnforceRange
      header: Item { width: (sliceListView.width - appWallpaper.expandedWidth) / 2; height: 1 }
      footer: Item { width: (sliceListView.width - appWallpaper.expandedWidth) / 2; height: 1 }

      focus: appWallpaper.showing
      onVisibleChanged: {
        if (visible) forceActiveFocus()
      }

      Connections {
        target: appWallpaper
        function onShowingChanged() {
          if (appWallpaper.showing) {
            sliceListView.forceActiveFocus()
          }
        }
      }

      add: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Style.animEnter; easing.type: Easing.OutCubic }
        NumberAnimation { property: "scale"; from: 0.85; to: 1; duration: Style.animEnter; easing.type: Easing.OutCubic }
      }
      remove: Transition {
        NumberAnimation { property: "opacity"; to: 0; duration: Style.animNormal; easing.type: Easing.InCubic }
      }
      displaced: Transition {
        NumberAnimation { properties: "x,y"; duration: Style.animMedium; easing.type: Easing.OutCubic }
      }
      move: Transition {
        NumberAnimation { properties: "x,y"; duration: Style.animMedium; easing.type: Easing.OutCubic }
      }


      WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) {
          appWallpaper.interactionBlockerTimer.restart()
          if (event.angleDelta.y > 0 || event.angleDelta.x > 0) {
            appWallpaper.cyclePrev(1)
          } else if (event.angleDelta.y < 0 || event.angleDelta.x < 0) {
            appWallpaper.cycleNext(1)
          }
          event.accepted = true
        }
      }


      Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
          appWallpaper.showing = false
          event.accepted = true
          return
        }


        
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Right || event.key === Qt.Key_D || event.key === Qt.Key_Down || event.key === Qt.Key_S) {
          appWallpaper.cycleNext(); event.accepted = true; return
        }
        if (event.key === Qt.Key_Backtab || event.key === Qt.Key_Left || event.key === Qt.Key_A || event.key === Qt.Key_Up || event.key === Qt.Key_W) {
          appWallpaper.cyclePrev(); event.accepted = true; return
        }
if (event.text && event.text.length > 0 && !event.modifiers) {
          var c = event.text.charCodeAt(0)
          if (c >= 32 && c < 127) {
            searchInput.text += event.text
            searchInput.forceActiveFocus()
            event.accepted = true
            return
          }
        }

        if (event.key === Qt.Key_Backspace) {
          if (searchInput.text.length > 0) {
            searchInput.text = searchInput.text.slice(0, -1)
          }
          event.accepted = true
          return
        }

        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          if (sliceListView.currentIndex >= 0 && sliceListView.currentIndex < appWallpaper.wallpaperResults.count) {
            var app = appWallpaper.wallpaperResults.get(sliceListView.currentIndex)
            CaelestiaApi.visuals.wallpaper.setWallpaper(app.path)
            appWallpaper.showing = false
          }
          event.accepted = true
          return
        }

      }


      delegate: SliceDelegate {
        colors: appWallpaper.colors
        
        expandedWidth: appWallpaper.expandedWidth
        sliceWidth: appWallpaper.sliceWidth
        skewOffset: appWallpaper.skewOffset
        onActivated: function(item) {
          if (item) {
            CaelestiaApi.visuals.wallpaper.setWallpaper(item.path)
            appWallpaper.showing = false
          }
        }
      }
    }


    ListView {
      id: hexListView
      focus: appWallpaper.showing && visible
      Keys.onPressed: event => {

        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Right || event.key === Qt.Key_D || event.key === Qt.Key_Down || event.key === Qt.Key_S) {
          appWallpaper.cycleNext(); event.accepted = true; return
        }
        if (event.key === Qt.Key_Backtab || event.key === Qt.Key_Left || event.key === Qt.Key_A || event.key === Qt.Key_Up || event.key === Qt.Key_W) {
          appWallpaper.cyclePrev(); event.accepted = true; return
        }
      }
      visible: appWallpaper.cardVisible && appWallpaper.isHexMode
      anchors.top: cardContainer.top
      anchors.topMargin: appWallpaper.topBarHeight
      anchors.bottom: cardContainer.bottom
      anchors.bottomMargin: appWallpaper.bottomBarHeight
      anchors.left: cardContainer.left
      anchors.right: cardContainer.right
      orientation: ListView.Horizontal
      clip: true
      property int _rows: Config.hexRows
      property real _r: Config.hexRadius
      property real _gridSpacing: 6
      property real _hexW: _r * 2
      property real _hexH: Math.ceil(_r * 1.73205)
      property real _stepX: 1.5 * _r + _gridSpacing
      property real _stepY: _hexH + _gridSpacing
      property real _gridContentH: (_rows - 1) * _stepY + _hexH + _hexH / 2
      property real _yOffset: Math.max(0, (height - _gridContentH) / 2)
      property real _visibleBand: (Config.hexCols - 1) * _stepX + _hexW
      property real _fadeZone: (width - _visibleBand) / 2

      boundsBehavior: Flickable.StopAtBounds
      flickDeceleration: 1500
      maximumFlickVelocity: 3000
      cacheBuffer: _stepX * 2

      property bool _initialSnap: true
      onVisibleChanged: {
        if (visible) {
          _initialSnap = true
          highlightMoveDuration = 0
          var startCol = Math.min(Math.floor(Config.hexCols / 2), count - 1)
          if (startCol >= 0) { currentIndex = startCol; _selectedCol = startCol; _selectedRow = 0 }
          positionViewAtIndex(currentIndex, ListView.Center)
          _snapRestoreTimer.restart()
        }
      }

      Timer {
        id: _snapRestoreTimer
        interval: 50
        onTriggered: {
          hexListView.highlightMoveDuration = Style.animExpand
          hexListView._initialSnap = false
        }
      }

      model: (appWallpaper.cardVisible && appWallpaper.isHexMode)
        ? Math.ceil((appWallpaper.wallpaperResults ? appWallpaper.wallpaperResults.count : 0) / Math.max(1, _rows))
        : 0

      spacing: 0
      keyNavigationEnabled: false
      highlightFollowsCurrentItem: true
      highlightMoveDuration: Style.animExpand
      highlight: Item {}
      preferredHighlightBegin: (width - _hexW) / 2
      preferredHighlightEnd: (width + _hexW) / 2
      highlightRangeMode: ListView.StrictlyEnforceRange

      header: Item { width: (hexListView.width - hexListView._hexW) / 2 }
      footer: Item { width: (hexListView.width - hexListView._hexW) / 2 }

      add: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Style.animEnter; easing.type: Easing.OutCubic }
        NumberAnimation { property: "scale"; from: 0.9; to: 1; duration: Style.animEnter; easing.type: Easing.OutCubic }
      }
      remove: Transition {
        NumberAnimation { property: "opacity"; to: 0; duration: Style.animNormal; easing.type: Easing.InCubic }
      }
      displaced: Transition {
        NumberAnimation { properties: "x,y"; duration: Style.animMedium; easing.type: Easing.OutCubic }
      }


      WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) {
          appWallpaper.interactionBlockerTimer.restart()
          if (event.angleDelta.y > 0 || event.angleDelta.x > 0) {
            appWallpaper.cyclePrev(1)
          } else if (event.angleDelta.y < 0 || event.angleDelta.x < 0) {
            appWallpaper.cycleNext(1)
          }
          event.accepted = true
        }
      }


      property int _selectedCol: currentIndex
      property int _selectedRow: 0

      delegate: Item {
        id: hexCol
        width: hexListView._stepX
        height: hexListView.height
        clip: false
        property int colIdx: index

        readonly property real _colCenter: (x - hexListView.contentX) + width * 0.5
        readonly property bool _insideView: _colCenter > -hexListView._hexW && _colCenter < hexListView.width + hexListView._hexW
        readonly property bool _nearEdge: _colCenter < hexListView._fadeZone || _colCenter > (hexListView.width - hexListView._fadeZone)
        readonly property bool _nearLeft: _colCenter < hexListView.width / 2
        readonly property bool _visible: _insideView && !_nearEdge
        property real _colScale: _visible ? 1 : 0
        Behavior on _colScale { enabled: !hexListView._initialSnap; NumberAnimation { duration: Style.animExpand; easing.type: Easing.OutCubic } }

        property real _arcFactor: Config.hexArc ? Config.hexArcIntensity : 0
        Behavior on _arcFactor { NumberAnimation { duration: Style.animExpand; easing.type: Easing.OutCubic } }

        readonly property real _arcOffset: {
          if (_arcFactor === 0) return 0
          var viewCenterX = hexListView.width / 2
          var normalized = (_colCenter - viewCenterX) / Math.max(1, viewCenterX)
          return -normalized * normalized * hexListView._r * _arcFactor
        }

        Repeater {
          id: hexCellRepeater
          property var _items: {
            var arr = []
            var start = hexCol.colIdx * hexListView._rows
            var end = Math.min(start + hexListView._rows, appWallpaper.wallpaperResults ? appWallpaper.wallpaperResults.count : 0)
            for (var i = start; i < end; i++) {
              var r = appWallpaper.wallpaperResults.get(i)
              if (r) arr.push({ row: r, rowIdx: i - start, flatIdx: i })
            }
            return arr
          }
          model: _items

          HexDelegate {
            required property var modelData
            readonly property int rowIdx: modelData.rowIdx
            readonly property int flatIdx: modelData.flatIdx

            hexRadius: hexListView._r
            colors: appWallpaper.colors
            
            itemData: modelData.row
            isSelected: hexCol.colIdx === hexListView._selectedCol && rowIdx === hexListView._selectedRow

            x: 0
            y: hexListView._yOffset + rowIdx * hexListView._stepY + (hexCol.colIdx % 2 !== 0 ? hexListView._hexH / 2 : 0) + hexCol._arcOffset

            scale: hexCol._colScale
            transformOrigin: hexCol._nearLeft ? Item.Left : Item.Right
            opacity: hexCol._colScale < 0.01 ? 0 : 1

            onHoverSelected: {
              hexListView._selectedCol = hexCol.colIdx
              hexListView._selectedRow = rowIdx
            }
            onActivated: function(item) {
              if (item) {
                CaelestiaApi.visuals.wallpaper.setWallpaper(item.path)
                appWallpaper.showing = false
              }
            }
          }
        }
      }
    }


    GridView {
      id: thumbGridView
      focus: appWallpaper.showing && visible
      Keys.onPressed: event => {

        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Right || event.key === Qt.Key_D || event.key === Qt.Key_Down || event.key === Qt.Key_S) {
          appWallpaper.cycleNext(); event.accepted = true; return
        }
        if (event.key === Qt.Key_Backtab || event.key === Qt.Key_Left || event.key === Qt.Key_A || event.key === Qt.Key_Up || event.key === Qt.Key_W) {
          appWallpaper.cyclePrev(); event.accepted = true; return
        }
      }
      visible: appWallpaper.cardVisible && appWallpaper.isGridMode
      anchors.top: cardContainer.top
      anchors.topMargin: appWallpaper.topBarHeight
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.horizontalCenterOffset: appWallpaper._gridCellGap / 2
      width: appWallpaper._gridTotalW
      height: appWallpaper._gridTotalH
      cellWidth: Config.gridThumbWidth + appWallpaper._gridCellGap
      cellHeight: Config.gridThumbHeight + appWallpaper._gridCellGap
      clip: true
      model: appWallpaper.cardVisible && appWallpaper.isGridMode ? appWallpaper.wallpaperResults : null
      keyNavigationEnabled: false
      cacheBuffer: 300
      boundsBehavior: Flickable.StopAtBounds
      
      
      interactive: false

      property real _scrollTarget: 0
      onContentYChanged: {
        if (!_gridScrollAnim.running) _scrollTarget = contentY
      }

      NumberAnimation {
        id: _gridScrollAnim
        target: thumbGridView
        property: "contentY"
        duration: 400
        easing.type: Easing.OutCubic
      }

      function _snapScroll(delta) {
        if (!_gridScrollAnim.running) _scrollTarget = contentY
        var step = cellHeight
        _scrollTarget += (delta > 0 ? -step : step)
        var maxY = Math.max(0, contentHeight - height)
        _scrollTarget = Math.max(0, Math.min(_scrollTarget, maxY))
        _gridScrollAnim.stop()
        _gridScrollAnim.from = contentY
        _gridScrollAnim.to = _scrollTarget
        _gridScrollAnim.start()
      }

      function _snapScrollTo(target) {
        var maxY = Math.max(0, contentHeight - height)
        _scrollTarget = Math.max(0, Math.min(target, maxY))
        _gridScrollAnim.stop()
        _gridScrollAnim.from = contentY
        _gridScrollAnim.to = _scrollTarget
        _gridScrollAnim.start()
      }

      function _ensureVisible(idx) {
        var cols = Math.max(1, Math.floor(width / cellWidth))
        var row = Math.floor(idx / cols)
        var rowTop = row * cellHeight
        var rowBottom = rowTop + cellHeight
        if (rowTop < contentY) _snapScrollTo(rowTop)
        else if (rowBottom > contentY + height) _snapScrollTo(rowBottom - height)
      }


      WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) {
          appWallpaper.interactionBlockerTimer.restart()
          if (event.angleDelta.y > 0 || event.angleDelta.x > 0) {
            appWallpaper.cyclePrev(1)
          } else if (event.angleDelta.y < 0 || event.angleDelta.x < 0) {
            appWallpaper.cycleNext(1)
          }
          event.accepted = true
        }
      }


      add: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Style.animEnter; easing.type: Easing.OutCubic }
        NumberAnimation { property: "scale"; from: 0.9; to: 1; duration: Style.animEnter; easing.type: Easing.OutCubic }
      }
      remove: Transition {
        NumberAnimation { property: "opacity"; to: 0; duration: Style.animNormal; easing.type: Easing.InCubic }
      }
      displaced: Transition {
        NumberAnimation { properties: "x,y"; duration: Style.animMedium; easing.type: Easing.OutCubic }
      }

      delegate: Rectangle {
        width: Config.gridThumbWidth
        height: Config.gridThumbHeight
        radius: 6
        color: Qt.rgba(appWallpaper.colors.surfaceContainer.r, appWallpaper.colors.surfaceContainer.g, appWallpaper.colors.surfaceContainer.b, 0.85)
        border.width: _gridMouse.containsMouse ? 2 : 0
        border.color: appWallpaper.colors.primary
        clip: true

        readonly property bool _preferGlyph: false

        CachingImage {
          anchors.fill: parent
          path: Images.isVideo(modelData.name) ? CaelestiaApi.visuals.wallpaper.thumbFor(modelData.path) : modelData.path
          horizontalAlignment: Image.AlignHCenter
          verticalAlignment: Image.AlignVCenter
          smooth: true
        }

        Text {
          anchors.centerIn: parent
          visible: Images.isVideo(modelData.name)
          text: "\ue04b"
          font.family: Style.fontFamilyIcons
          font.pixelSize: Math.min(parent.width, parent.height) * 0.45
          color: Qt.rgba(appWallpaper.colors.primary.r, appWallpaper.colors.primary.g, appWallpaper.colors.primary.b, 0.85)
        }

        Rectangle {
          anchors.fill: parent
          color: Qt.rgba(0, 0, 0, _gridMouse.containsMouse ? 0.15 : 0.4)
          Behavior on color { ColorAnimation { duration: 150 } }
        }

        Text {
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 6
          anchors.horizontalCenter: parent.horizontalCenter
          text: (modelData.name || "").toUpperCase()
          font.family: Style.fontFamily
          font.pixelSize: 10
          font.weight: Font.Bold
          color: "#fff"
        }

        MouseArea {
          id: _gridMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            CaelestiaApi.visuals.wallpaper.setWallpaper(modelData.path)
            appWallpaper.showing = false
          }
        }
      }
    }

    Row {
      id: sourceFilterRow
      anchors.bottom: cardContainer.bottom
      anchors.bottomMargin: 25
      anchors.horizontalCenter: parent.horizontalCenter
      visible: appWallpaper.cardVisible
      z: 11
      spacing: ShellConfig.Tokens.spacing.small

      IconTextButton {
          text: qsTr("Images")
          icon: "image"
          type: CaelestiaApi.visuals.wallpaper.currentMediaFilter === "Image" ? TextButton.Filled : TextButton.Tonal
          onClicked: CaelestiaApi.visuals.wallpaper.currentMediaFilter = (CaelestiaApi.visuals.wallpaper.currentMediaFilter === "Image") ? "All" : "Image"
      }
      IconTextButton {
          text: qsTr("Animated")
          icon: "animation"
          type: CaelestiaApi.visuals.wallpaper.currentMediaFilter === "Animated" ? TextButton.Filled : TextButton.Tonal
          onClicked: CaelestiaApi.visuals.wallpaper.currentMediaFilter = (CaelestiaApi.visuals.wallpaper.currentMediaFilter === "Animated") ? "All" : "Animated"
      }
      IconTextButton {
          text: qsTr("Videos")
          icon: "videocam"
          type: CaelestiaApi.visuals.wallpaper.currentMediaFilter === "Video" ? TextButton.Filled : TextButton.Tonal
          onClicked: CaelestiaApi.visuals.wallpaper.currentMediaFilter = (CaelestiaApi.visuals.wallpaper.currentMediaFilter === "Video") ? "All" : "Video"
      }
    }
  FocusScope {
          id: funnelScope
          visible: !appWallpaper.isMainScreen
          enabled: !appWallpaper.isMainScreen
          anchors.fill: parent
          focus: !appWallpaper.isMainScreen
          activeFocusOnTab: false

          Component.onCompleted: { if (!appWallpaper.isMainScreen) forceActiveFocus() }
          onActiveFocusChanged: { if (!activeFocus && !appWallpaper.isMainScreen) forceActiveFocus() }

          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
              appWallpaper.showing = false
              event.accepted = true
              return
            }
            if (event.text && event.text.length > 0 && !event.modifiers) {
              var c = event.text.charCodeAt(0)
              if (c >= 32 && c < 127) {
                searchInput.text += event.text
                event.accepted = true
                return
              }
            }
            if (event.key === Qt.Key_Backspace) {
              if (searchInput.text.length > 0) {
                searchInput.text = searchInput.text.slice(0, -1)
              }
              event.accepted = true
              return
            }
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              if (sliceListView.currentIndex >= 0 && sliceListView.currentIndex < CaelestiaApi.visuals.wallpaper.results.count) {
                var app = CaelestiaApi.visuals.wallpaper.results.get(sliceListView.currentIndex)
                CaelestiaApi.visuals.wallpaper.setWallpaper(app.path)
                appWallpaper.showing = false
              }
              event.accepted = true
              return
            }
            if (event.key === Qt.Key_Left) {
              if (sliceListView.currentIndex > 0) sliceListView.currentIndex--
              event.accepted = true
              return
            }
            if (event.key === Qt.Key_Right) {
              if (sliceListView.currentIndex < CaelestiaApi.visuals.wallpaper.results.count - 1) sliceListView.currentIndex++
              event.accepted = true
              return
            }
          }

          HoverHandler {
            acceptedDevices: PointerDevice.AllDevices
            onHoveredChanged: if (hovered) funnelScope.forceActiveFocus()
          }
        }
}