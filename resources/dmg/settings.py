from os.path import basename as _basename


def _to_rect(bounds):
    """See the TIP section of: https://www.macosxautomation.com/applescript/firsttutorial/11.html"""
    bounds = [int(s) for s in bounds.split(",")]
    return [bounds[:2], [bounds[2] - bounds[0], bounds[3] - bounds[1]]]


# Settings reference: https://dmgbuild.readthedocs.io/en/latest/settings.html
# Sample w/ defaults: https://dmgbuild.readthedocs.io/en/latest/example.html

format = "UDZO"
compression_level = 9
filesystem = "HFS+"
size = "512000k"

icon = defines["volume_icon"]
_pkg = defines["pkg"]
files = [_pkg]

# set current view of container window to icon view
default_view = "icon-view"
# set toolbar visible of container window to false
show_toolbar = False
# set statusbar visible of container window to false
show_status_bar = False
# set the bounds of container window to {<%= window_bounds %>}
window_rect = _to_rect(defines["window_bounds"])
# set theViewOptions to the icon view options of container window
include_icon_view_settings = True
# set arrangement of theViewOptions to not arranged
arrange_by = None
# set icon size of theViewOptions to 72
icon_size = 72
# set background picture of theViewOptions to file ".support:background.png"
background = defines["background"]
# set position of item "<%= pkg_name %>" of container window to {<%= pkg_position %>}
icon_locations = {(_basename(_pkg)): [int(s) for s in defines["pkg_position"].split(",")]}
