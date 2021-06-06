// params ["_function",["_params",[],[[]]]];


params["_function"];

if (_function == "INIT") then {
	// diag_log ["INIT"];

	ocap_markers_tracked = []; // Markers which we saves into replay


	[] spawn {

		[
			{!isNil {missionNamespace getVariable "ocap_markers_handle"} && count allPlayers > 0},
			{
				{
					// "Started polling starting markers" remoteExec ["hint", 0];
					// get intro object markers
					(_x call BIS_fnc_markerParams) params ["_nameArray", "_position", "_size", "_colour", "_type", "_brush", "_shape", "_alpha", "_text"];
					_position params ["_posX", "_posY"];
					_nameArray params ["_marker"];
					_size params ["_a", "_b"];

					_dir = 0;
					_shape = "ICON";
					if (_type == "") then {_type = "mil_dot"};

					if (["ObjectMarker", _marker] call BIS_fnc_inString) then {
						_type = "ObjectMarker";
						_colour = "ColorBlack";
					};
					if (["moduleCoverMap_dot", _marker] call BIS_fnc_inString) then {
						_type = "moduleCoverMap";
						_colour = "ColorBlack";
					};
					if (["safeMarker", _marker] call BIS_fnc_inString) then {
						_type = "safeStart";
						_colour = "ColorBlack";
					};

					_exclude = [
						"bis_fnc_moduleCoverMap_0",
						"bis_fnc_moduleCoverMap_90",
						"bis_fnc_moduleCoverMap_180",
						"bis_fnc_moduleCoverMap_270",
						"bis_fnc_moduleCoverMap_border",
						"respawn",
						"respawn_west",
						"respawn_east",
						"respawn_guerrila",
						"respawn_civilian"
					];

					if (!(_marker in _exclude)) then {
						_randomizedOwner = allPlayers # 0;
						_forceGlobal = true;
						["fnf_ocap_handleMarker", ["CREATED", _marker, _randomizedOwner, _position, _type, _shape, [1,1], _dir, _brush, _colour, 1, _text, _forceGlobal]] call CBA_fnc_localEvent;
						// "debug_console" callExtension (str [_marker, _randomizedOwner, _position, _type, _shape, [1,1], _dir, _brush, _colour, 1, _text] + "#0100");
					};

				} forEach allMapMarkers;
			}
		] call CBA_fnc_waitUntilAndExecute;
	};
	

	{
		// handle created markers
		addMissionEventHandler["MarkerCreated", {
			params["_marker", "_channelNumber", "_owner", "_local"];

			if (!_local) exitWith {};

			_pos = getMarkerPos _marker;
			_type = getMarkerType _marker;
			_shape = "ICON";
			_dir = markerDir _marker;
			_brush = markerBrush _marker;
			_color = markerColor _marker;
			_text = markerText _marker;

			diag_log text format["OCAPLOG: Sending data from %1 with param CREATED and name ""%2""", _owner, _marker];

			["fnf_ocap_handleMarker", ["CREATED", _marker, _owner, _pos, _type, _shape, [1,1], _dir, _brush, _color, 1, _text]] call CBA_fnc_serverEvent;
		}];

		// handle marker moves/updates
		addMissionEventHandler["MarkerUpdated", {
			params["_marker", "_local"];

			if (!_local) exitWith {};
			diag_log text format["OCAPLOG: Sent data from %1 with param UPDATED and name ""%2""", player, _marker];

			["fnf_ocap_handleMarker", ["UPDATED", _marker, player, markerPos _marker]] call CBA_fnc_serverEvent;
		}];

		// handle marker deletions
		addMissionEventHandler["MarkerDeleted", {
				params["_marker", "_local"];

				if (!_local) exitWith {};
				diag_log text format["OCAPLOG: Sent data from %1 with param DELETED and name ""%2""", player, _marker];

				["fnf_ocap_handleMarker", ["DELETED", _marker, player]] call CBA_fnc_serverEvent;
			}];
	} remoteExec["call", 0, true];

};





ocap_markers_handle = ["fnf_ocap_handleMarker", {

	params["_eventType", "_mrk_name", "_mrk_owner","_pos", "_type", "_shape", "_size", "_dir", "_brush", "_color", "_alpha", "_text", "_forceGlobal"];


	diag_log text format["OCAPLOG: SERVER: Received data --
%1 ",_this];

	switch (_eventType) do {

		case "CREATED":{

			diag_log text format["OCAPLOG: SERVER: Entered CREATED %1 with details:
dir: %2
color: %3
type: %4
text: %5
pos: %6",
_mrk_name,
_dir,
_color,
_type,
_text,
_pos
];

			// if (_mrk in ocap_markers_tracked || _mrk_type == "") exitWith {};

			diag_log text format["OCAPLOG: SERVER: Valid CREATED process of marker from %1 for ""%2""", _mrk_owner, _mrk_name];

			if (_type isEqualTo "") exitWith {};
			ocap_markers_tracked pushBackUnique _mrk_name;

			_mrk_color = getarray (configfile >> "CfgMarkerColors" >> _color >> "color") call bis_fnc_colorRGBtoHTML;

			// _sideOfMarker = -1;
			// if (_mrk_owner isEqualTo "") then {
			// } else {
			_sideOfMarker = (side _mrk_owner) call BIS_fnc_sideID;
			if (_sideOfMarker isEqualTo 4 || 
			(["Projectile#", _mrk_name] call BIS_fnc_inString) || 
			(["Detonation#", _mrk_name] call BIS_fnc_inString) || 
			(["Mine#", _mrk_name] call BIS_fnc_inString) ||
			(["ObjectMarker", _mrk_name] call BIS_fnc_inString) ||
			(["moduleCoverMap", _mrk_name] call BIS_fnc_inString) ||
			_forceGlobal) then {_sideOfMarker = -1};
			// };

			diag_log text format["OCAPLOG: SERVER: Valid CREATED process of %1, sending to extension --
%2 ", _mrk_name, [_mrk_name, 0, _type, _text, ocap_captureFrameNo, -1, _mrk_owner getVariable["ocap_id", 0], _mrk_color, [1, 1], _sideOfMarker, _pos]];

			[":MARKER:CREATE:", [_mrk_name, 0, _type, _text, ocap_captureFrameNo, -1, _mrk_owner getVariable["ocap_id", 0], _mrk_color, [1, 1], _sideOfMarker, _pos]] call ocap_fnc_extension;

		};

		case "UPDATED":{

			// diag_log format ["OCAPLOG: SERVER: Enter UPDATED process of %1 from %2 --
			// %3", _mrk, _mrk_owner, _mrk call BIS_fnc_markerToString];

			if (_mrk_name in ocap_markers_tracked) then {
				// 				diag_log format ["OCAPLOG: SERVER: Valid UPDATED process of %1, sending to extension --
				// %2", _mrk, _mrk call BIS_fnc_markerToString];
				[":MARKER:MOVE:", [_mrk_name, ocap_captureFrameNo, _pos]] call ocap_fnc_extension;
			};
		};

		case "DELETED":{
			// diag_log format ["OCAPLOG: SERVER: Enter DELETED process of %1 from %2 --
			// %3", _mrk_info, _mrk_owner, _mrk call BIS_fnc_markerToString];

			if (_mrk_name in ocap_markers_tracked) then {
				// 				diag_log format ["OCAPLOG: SERVER: Valid DELETED process of %1, sending to extension --
				// %2", _mrk_info, _mrk call BIS_fnc_markerToString];
				[":MARKER:DELETE:", [_mrk_name, ocap_captureFrameNo]] call ocap_fnc_extension;
				ocap_markers_tracked = ocap_markers_tracked - [_mrk_name];
			};
		};
	};
}] call CBA_fnc_addEventHandler;