// Integration fragment for the isolated left-inset trial.
// Merge into the client cl_minimap.gnut that owns the stock `file` state.
// This is not a standalone Northstar mod.
//
// Call this instead of CreateCockpitRui for every minimap RUI (base, wedges,
// player marker, indicator, entity markers, pings and custom layers). Change
// those minimap RUIs' draw group from RUI_DRAW_COCKPIT to RUI_DRAW_HUD.

var function BT7274_CreateMinimapInsetRui( asset ruiAsset, int sortKey )
{
	if ( file.bt7274MinimapInsetTopology == null )
	{
		float[2] screenSize = GetScreenSize()
		float insetSide = min( screenSize[0] * 0.32, screenSize[1] * 0.42 )

		// HUD topology coordinates are pixels; origin is the top-left corner.
		// Equal side lengths make the viewport square.
		vector origin = <screenSize[0] * 0.02, screenSize[1] * 0.12, 0>
		vector right = <insetSide, 0, 0>
		vector down = <0, insetSide, 0>

		file.bt7274MinimapInsetTopology =
			RuiTopology_CreatePlane( origin, right, down, true )
	}

	return RuiCreate(
		ruiAsset,
		file.bt7274MinimapInsetTopology,
		RUI_DRAW_HUD,
		sortKey
	)
}

// Add this field to the stock minimap's `file` struct:
var bt7274MinimapInsetTopology = null
