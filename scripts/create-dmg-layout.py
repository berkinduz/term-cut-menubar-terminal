"""Regenerate Finder metadata with the optional `ds-store` Python package."""

from pathlib import Path

from ds_store import DSStore


destination = Path(__file__).resolve().parent.parent / "Resources/DMG/FinderLayout.dsstore"
destination.parent.mkdir(parents=True, exist_ok=True)
with DSStore.open(str(destination), "w+") as layout:
    layout["."]["vSrn"] = ("long", 1)
    layout["."]["icvl"] = ("type", "icnv")
    layout["."]["bwsp"] = {
        "ShowToolbar": False,
        "ShowStatusBar": False,
        "ShowSidebar": False,
        "ContainerShowSidebar": False,
        "PreviewPaneVisibility": False,
        "SidebarWidth": 0,
        "ShowPathbar": False,
        "ShowTabView": False,
        "WindowBounds": "{{160, 160}, {560, 320}}",
    }
    layout["."]["icvp"] = {
        "viewOptionsVersion": 1,
        "backgroundType": 0,
        "backgroundColorRed": 1.0,
        "backgroundColorGreen": 1.0,
        "backgroundColorBlue": 1.0,
        "arrangeBy": "none",
        "iconSize": 96.0,
        "textSize": 13.0,
        "labelOnBottom": True,
        "gridOffsetX": 0.0,
        "gridOffsetY": 0.0,
        "gridSpacing": 100.0,
        "scrollPositionX": 0.0,
        "scrollPositionY": 0.0,
        "showIconPreview": True,
        "showItemInfo": False,
    }
    layout["Peeksh.app"]["Iloc"] = (140, 130)
    layout["Applications"]["Iloc"] = (420, 130)
