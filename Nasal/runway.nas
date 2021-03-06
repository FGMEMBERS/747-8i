# Copyright (C) 2014  onox
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

var copilot_say = func (message) {
    setprop("/sim/messages/copilot", message);
#    logger.info(sprintf("Announcing '%s'", message));
};

var on_short_runway_format = func {
    var distance = takeoff_announcer.get_short_runway_distance();
    return sprintf("On runway .. %%s .. %d %s remaining", distance, takeoff_config.distances_unit);
};

var approaching_short_runway_format = func {
    var distance = takeoff_announcer.get_short_runway_distance();
    return sprintf("Approaching .. %%s .. %d %s available", distance, takeoff_config.distances_unit);
};

var remaining_distance_format = func {
    return sprintf("%%d %s remaining", landing_config.distances_unit);
};

var takeoff_config = { parents: [runway.TakeoffRunwayAnnounceConfig] };
takeoff_config.distances_unit = "feet";

# Will cause the announcer to emit the "on-runway" signal if the
# aircraft is at most 15 meters from the center line of the runway
takeoff_config.distance_center_line_m = 15;

# Let the announcer emit the "approaching-runway" signal if the
# aircraft comes within 200 meters of the runway
takeoff_config.distance_edge_max_m = 200;

var landing_config = { parents: [runway.LandingRunwayAnnounceConfig] };
landing_config.distances_unit = "feet";
landing_config.distance_center_nose_m = 37;

# Create announcers
var takeoff_announcer = runway.TakeoffRunwayAnnounceClass.new(takeoff_config);
var landing_announcer = runway.LandingRunwayAnnounceClass.new(landing_config);

var stop_announcer    = runway.make_stop_announcer_func(takeoff_announcer, landing_announcer);
var switch_to_takeoff = runway.make_switch_to_takeoff_func(takeoff_announcer, landing_announcer);

takeoff_announcer.connect("on-runway", runway.make_betty_cb(copilot_say, "On runway .. %s", switch_to_takeoff, runway.runway_number_filter));
takeoff_announcer.connect("on-short-runway", runway.make_betty_cb(copilot_say, on_short_runway_format, switch_to_takeoff, runway.runway_number_filter));
takeoff_announcer.connect("approaching-runway", runway.make_betty_cb(copilot_say, "Approaching .. %s", nil, runway.runway_number_filter));
takeoff_announcer.connect("approaching-short-runway", runway.make_betty_cb(copilot_say, approaching_short_runway_format, nil, runway.runway_number_filter));

landing_announcer.connect("remaining-distance", runway.make_betty_cb(copilot_say, remaining_distance_format));
landing_announcer.connect("vacated-runway", runway.make_betty_cb(copilot_say, "Vacated runway .. %s", stop_announcer, runway.runway_number_filter));
landing_announcer.connect("landed-runway", runway.make_betty_cb(copilot_say, "Touchdown on runway .. %s", nil, runway.runway_number_filter));
landing_announcer.connect("landed-outside-runway", runway.make_betty_cb(nil, nil, stop_announcer));

var set_on_ground = runway.make_set_ground_func(takeoff_announcer, landing_announcer);
var init_takeoff  = runway.make_init_func(takeoff_announcer);

var init_announcers = func {
    setlistener("/gear/on-ground", func (node) {
        set_on_ground(node.getBoolValue());
    }, startup=0, runtime=0);
    init_takeoff();
};

setlistener("/sim/signals/fdm-initialized", func {
    var timer = maketimer(5.0, func init_announcers());
    timer.singleShot = 1;
    timer.start();
});
