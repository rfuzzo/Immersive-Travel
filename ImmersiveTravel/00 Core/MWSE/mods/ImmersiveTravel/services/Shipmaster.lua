---@type ServiceData
local this = {
  class = "Shipmaster",
  mount = "a_longboat",
  override_npc = {
    "rindral dralor",
    "Daynas Darys"
  },
  override_mount = {
    {
      id = "a_longboat",
      points = {
        "Vos",
        "Firewatch"
      }
    },
    {
      id = "a_longboat",
      points = {
        "Sadrith Mora",
        "Helnim"
      }
    },
    {
      id = "a_DE_ship",
      points = {
        "Vos",
        "Sadrith Mora",
        "Dagon Fel",
        "Ebonheart",
        "Fort Frostmoth",
        "Nivalis",
        "Bal Oyra",
        "Necrom, Waterfront",
        "Gorne",
        "Firewatch",
        "Helnim",
        "Old Ebonheart, Docks",
        "Andothren, Docks",
        "Almas Thirr"
      }
    }
  },
  ground_offset = 0,
  guide = {
    "it_guide_af",
    "it_guide_am",
    "it_guide_bf",
    "it_guide_bm",
    "it_guide_df",
    "it_guide_dm",
    "it_guide_hf",
    "it_guide_hm",
    "it_guide_if",
    "it_guide_im",
    "it_guide_kf",
    "it_guide_km",
    "it_guide_nf",
    "it_guide_nm",
    "it_guide_of",
    "it_guide_om",
    "it_guide_rf",
    "it_guide_rm",
    "it_guide_wf",
    "it_guide_wm",
  }
}

return this
