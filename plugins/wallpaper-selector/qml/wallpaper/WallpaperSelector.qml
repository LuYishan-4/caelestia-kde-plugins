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
import "components" as Components
import "views" as Views

PanelWindow {
  id: appWallpaper
  
  property var colors
  property bool showing: false
  property bool isMainScreen: true
  
  property var wallpaperResults: ScriptModel {
    values: {
      var _dummy = CaelestiaApi.visuals.wallpaper.list;
      return CaelestiaApi.visuals.wallpaper.query(topSearchBar.text);
    }
  }

  onShowingChanged: {
    if (showing) {
      if (topSearchBar.text !== "") {
          topSearchBar.text = ""
      }
      cardShowTimer.restart()
    } else {
      cardVisible = false
      if (typeof CaelestiaApi.visuals.wallpaper.stopPreview === "function") {
          CaelestiaApi.visuals.wallpaper.stopPreview()
      }
      if (topSearchBar.text !== "") {
          topSearchBar.text = ""
      }
    }
  }

  function closeRequested() {
      if (typeof settingsPanel !== "undefined" && settingsPanel.showing) {
          settingsPanel.showing = false;
      } else {
          appWallpaper.showing = false;
      }
  }

  Connections {
      target: typeof settingsPanel !== "undefined" ? settingsPanel : null
      function onShowingChanged() {
          if (settingsPanel.showing) root.settingsOpenCount++
          else root.settingsOpenCount--
      }
  }

  Connections {
      target: root
      function onCloseSettingsRequested() {
          if (typeof settingsPanel !== "undefined") {
              settingsPanel.showing = false
          }
      }
  }

  Timer {
    id: cardShowTimer
    interval: 50
    onTriggered: {
        appWallpaper.cardVisible = true
        scrollTimer.restart()
    }
  }

  Timer {
      id: scrollTimer
      interval: 100
      onTriggered: {
          appWallpaper.scrollToCurrent()
      }
  }




  function scrollToCurrent() {
      var currentPath = String(CaelestiaApi.visuals.wallpaper.current || "").replace(/^file:\/\//, "").trim()
      
      var targetIdx = -1
      var arr = appWallpaper.wallpaperResults ? appWallpaper.wallpaperResults.values : []
      if (arr && arr.length > 0) {
          for (var i = 0; i < arr.length; i++) {
            var w = arr[i]
            if (w && w.path) {
              var wp = String(w.path).replace(/^file:\/\//, "").trim()
              if (wp === currentPath) {
                targetIdx = i
                break
              }
            }
          }
      }
      
      if (targetIdx >= 0) {
        if (appWallpaper.isSliceMode) {
          sliceListView.currentIndex = targetIdx
          sliceListView.positionViewAtIndex(targetIdx, ListView.Center)
        } else if (appWallpaper.isHexMode) {
          hexListView.currentIndex = targetIdx
          hexListView._selectedCol = targetIdx
          hexListView.positionViewAtIndex(targetIdx, ListView.Center)
        } else if (appWallpaper.isGridMode) {
          thumbGridView.currentIndex = targetIdx
          thumbGridView._ensureVisible(targetIdx)
        }
      }
  }



  Timer {
    id: focusTimer
    interval: 50
    onTriggered: {
      if (appWallpaper.isSliceMode) sliceListView.forceActiveFocus()
      else if (appWallpaper.isHexMode) hexListView.forceActiveFocus()
      else if (appWallpaper.isGridMode) thumbGridView.forceActiveFocus()
    }
  }

  property int sliceWidth: Config.sliceWidth
  
  Shortcut {
    sequences: ["Tab", "Right", "Down"]
    onActivated: appWallpaper.cycleNext()
    enabled: appWallpaper.cardVisible && appWallpaper.isMainScreen && !topSearchBar.activeFocus
  }

  Shortcut {
    sequences: ["Shift+Tab", "Left", "Up"]
    onActivated: appWallpaper.cyclePrev()
    enabled: appWallpaper.cardVisible && appWallpaper.isMainScreen && !topSearchBar.activeFocus
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
    if (appWallpaper.wallpaperResults.values && appWallpaper.wallpaperResults.values.length > 0)
      sliceListView.positionViewAtIndex(0, ListView.Beginning)
  }

  Timer {
    id: interactionBlockerTimer
    interval: 300
  }
  property bool blockHover: interactionBlockerTimer.running

  function cycleNext(step) {
      if (!appWallpaper.wallpaperResults.values || appWallpaper.wallpaperResults.values.length === 0) return
      interactionBlockerTimer.restart()
      var s = step || 1
      var nextIdx = 0
      var count = appWallpaper.wallpaperResults.values.length
      if (appWallpaper.isSliceMode) {
        nextIdx = (sliceListView.currentIndex + s) % count
        if (nextIdx < 0) nextIdx += count
        sliceListView.currentIndex = nextIdx
      } else if (appWallpaper.isHexMode) {
        nextIdx = (hexListView.currentIndex + s) % count
        if (nextIdx < 0) nextIdx += count
        hexListView.currentIndex = nextIdx
        hexListView._selectedCol = nextIdx
      } else if (appWallpaper.isGridMode) {
        nextIdx = (thumbGridView.currentIndex + s) % count
        if (nextIdx < 0) nextIdx += count
        thumbGridView.currentIndex = nextIdx
      }
  }

  function cyclePrev(step) {
      if (!appWallpaper.wallpaperResults.values || appWallpaper.wallpaperResults.values.length === 0) return
      interactionBlockerTimer.restart()
      var s = step || 1
      var nextIdx = 0
      var count = appWallpaper.wallpaperResults.values.length
      if (appWallpaper.isSliceMode) {
        nextIdx = (sliceListView.currentIndex - s) % count
        if (nextIdx < 0) nextIdx += count
        sliceListView.currentIndex = nextIdx
      } else if (appWallpaper.isHexMode) {
        nextIdx = (hexListView.currentIndex - s) % count
        if (nextIdx < 0) nextIdx += count
        hexListView.currentIndex = nextIdx
        hexListView._selectedCol = nextIdx
      } else if (appWallpaper.isGridMode) {
        nextIdx = (thumbGridView.currentIndex - s) % count
        if (nextIdx < 0) nextIdx += count
        thumbGridView.currentIndex = nextIdx
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
    onClicked: appWallpaper.closeRequested()
  }

  Item {
      id: cardContainer

      width: appWallpaper.cardWidth
      height: appWallpaper.cardHeight
      anchors.centerIn: parent
      visible: appWallpaper.showing && appWallpaper.cardVisible && appWallpaper.isMainScreen

      property bool animateIn: appWallpaper.cardVisible

      onVisibleChanged: {
      }

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

        Components.TopSearchBar {
            id: topSearchBar
            anchors.top: parent.top
            anchors.topMargin: 25
            anchors.horizontalCenter: parent.horizontalCenter
            z: 11
            colors: appWallpaper.colors

            onAccepted: {
                var currentView = appWallpaper.isSliceMode ? sliceListView : (appWallpaper.isHexMode ? hexListView : thumbGridView)
                if (currentView.currentIndex >= 0 && appWallpaper.wallpaperResults.values && currentView.currentIndex < appWallpaper.wallpaperResults.values.length) {
                    var wall = appWallpaper.wallpaperResults.values ? appWallpaper.wallpaperResults.values[currentView.currentIndex] : null
                    CaelestiaApi.visuals.wallpaper.setWallpaper(wall.path)
                    appWallpaper.closeRequested()
                }
            }
            onEscapePressed: appWallpaper.closeRequested()
        }

        IconButton {
            id: floatingSettingsBtn
            icon: "settings"
            type: IconButton.Tonal
            anchors.left: topSearchBar.right
            anchors.leftMargin: 16
            anchors.verticalCenter: topSearchBar.verticalCenter
            z: 11
            onClicked: settingsPanel.showing = !settingsPanel.showing
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

    Views.SliceView {
        id: sliceListView
        visible: appWallpaper.cardVisible && appWallpaper.isSliceMode
        anchors.top: cardContainer.top
        anchors.topMargin: appWallpaper.topBarHeight
        anchors.bottom: cardContainer.bottom
        anchors.bottomMargin: appWallpaper.bottomBarHeight
        anchors.horizontalCenter: parent.horizontalCenter
        
        colors: appWallpaper.colors
        model: appWallpaper.cardVisible && appWallpaper.isSliceMode ? appWallpaper.wallpaperResults : null
        visibleCount: appWallpaper.visibleCount
        expandedWidth: appWallpaper.expandedWidth
        sliceWidth: appWallpaper.sliceWidth
        sliceSpacing: appWallpaper.sliceSpacing
        skewOffset: appWallpaper.skewOffset

        focus: appWallpaper.showing
        onVisibleChanged: {
            if (visible) forceActiveFocus()
        }

        Connections {
            target: appWallpaper
            function onShowingChanged() {
                if (appWallpaper.showing && appWallpaper.isSliceMode) {
                    sliceListView.forceActiveFocus()
                }
            }
        }

        onCycleNext: step => appWallpaper.cycleNext(step)
        onCyclePrev: step => appWallpaper.cyclePrev(step)
        onWallpaperSelected: path => {
            CaelestiaApi.visuals.wallpaper.setWallpaper(path)
            appWallpaper.closeRequested()
        }
        onCurrentIndexChanged: {
            if (currentIndex >= 0 && appWallpaper.wallpaperResults.values && currentIndex < appWallpaper.wallpaperResults.values.length) {
                var wall = appWallpaper.wallpaperResults.values[currentIndex]
                if (wall) CaelestiaApi.visuals.wallpaper.preview(wall.path)
            }
        }
        onEscapePressed: appWallpaper.closeRequested()
        onAppendSearchText: text => topSearchBar.appendSearchText(text)
        onBackspaceSearchText: () => topSearchBar.backspaceSearchText()
        onInteractionStarted: interactionBlockerTimer.restart()
    }

    Views.HexView {
        id: hexListView
        visible: appWallpaper.cardVisible && appWallpaper.isHexMode
        anchors.top: cardContainer.top
        anchors.topMargin: appWallpaper.topBarHeight
        anchors.bottom: cardContainer.bottom
        anchors.bottomMargin: appWallpaper.bottomBarHeight
        anchors.left: cardContainer.left
        anchors.right: cardContainer.right
        
        focus: appWallpaper.showing && visible
        
        colors: appWallpaper.colors
        model: (appWallpaper.cardVisible && appWallpaper.isHexMode) ? Math.ceil((appWallpaper.wallpaperResults.values ? appWallpaper.wallpaperResults.values.length : 0) / Math.max(1, Config.hexRows)) : 0
        
        onCycleNext: step => appWallpaper.cycleNext(step)
        onCyclePrev: step => appWallpaper.cyclePrev(step)
        onWallpaperSelected: path => {
            CaelestiaApi.visuals.wallpaper.setWallpaper(path)
            appWallpaper.closeRequested()
        }
        onCurrentIndexChanged: {
            if (currentIndex >= 0 && appWallpaper.wallpaperResults.values && currentIndex < appWallpaper.wallpaperResults.values.length) {
                var wall = appWallpaper.wallpaperResults.values[currentIndex]
                if (wall) CaelestiaApi.visuals.wallpaper.preview(wall.path)
            }
        }
        onEscapePressed: appWallpaper.closeRequested()
        onAppendSearchText: text => topSearchBar.appendSearchText(text)
        onBackspaceSearchText: () => topSearchBar.backspaceSearchText()
        onInteractionStarted: interactionBlockerTimer.restart()
    }

    Views.ThumbGridView {
        id: thumbGridView
        visible: appWallpaper.cardVisible && appWallpaper.isGridMode
        anchors.top: cardContainer.top
        anchors.topMargin: appWallpaper.topBarHeight
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: appWallpaper._gridCellGap / 2
        width: appWallpaper._gridTotalW
        height: appWallpaper._gridTotalH
        
        focus: appWallpaper.showing && visible
        
        colors: appWallpaper.colors
        model: appWallpaper.cardVisible && appWallpaper.isGridMode ? appWallpaper.wallpaperResults : null
        
        onCycleNext: step => appWallpaper.cycleNext(step)
        onCyclePrev: step => appWallpaper.cyclePrev(step)
        onWallpaperSelected: path => {
            CaelestiaApi.visuals.wallpaper.setWallpaper(path)
            appWallpaper.closeRequested()
        }
        onCurrentIndexChanged: {
            if (currentIndex >= 0 && appWallpaper.wallpaperResults.values && currentIndex < appWallpaper.wallpaperResults.values.length) {
                var wall = appWallpaper.wallpaperResults.values[currentIndex]
                if (wall) CaelestiaApi.visuals.wallpaper.preview(wall.path)
            }
        }
        onEscapePressed: appWallpaper.closeRequested()
        onAppendSearchText: text => topSearchBar.appendSearchText(text)
        onBackspaceSearchText: () => topSearchBar.backspaceSearchText()
        onInteractionStarted: interactionBlockerTimer.restart()
    }

    Components.FilterRow {
        id: sourceFilterRow
        anchors.bottom: cardContainer.bottom
        anchors.bottomMargin: 25
        anchors.horizontalCenter: parent.horizontalCenter
        visible: appWallpaper.cardVisible
        z: 11
    }

    Components.SettingsPanel {
        id: settingsPanel
        anchors.fill: parent
        z: 99
        colors: appWallpaper.colors
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
                appWallpaper.closeRequested()
                event.accepted = true
                return
            }
            if (event.text && event.text.length > 0 && !event.modifiers) {
                var c = event.text.charCodeAt(0)
                if (c >= 32 && c < 127) {
                    topSearchBar.appendSearchText(event.text)
                    event.accepted = true
                    return
                }
            }
            if (event.key === Qt.Key_Backspace) {
                topSearchBar.backspaceSearchText()
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                var currentView = appWallpaper.isSliceMode ? sliceListView : (appWallpaper.isHexMode ? hexListView : thumbGridView)
                if (currentView.currentIndex >= 0 && appWallpaper.wallpaperResults.values && currentView.currentIndex < appWallpaper.wallpaperResults.values.length) {
                    var app = appWallpaper.wallpaperResults.values ? appWallpaper.wallpaperResults.values[currentView.currentIndex] : null
                    CaelestiaApi.visuals.wallpaper.setWallpaper(app.path)
                    appWallpaper.closeRequested()
                }
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Left) {
                appWallpaper.cyclePrev(1)
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Right) {
                appWallpaper.cycleNext(1)
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