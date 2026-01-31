return {
  bio_techlab = {
    name                      = [[Биолаборатория]],
    description               = [[Выращивает куриц. Биолаборатория загнивающего запада из прямого репортажа РЕН ТВ]],
    buildDistance             = 300,
    builder                   = true,

    buildoptions              = {
      [[chicken]],
      [[chicken_leaper]],
      [[chickenr]],
      [[chicken_tiamat]],
      [[chicken_pigeon]],
      [[chicken_shield]],
      [[chicken_blimpy]],
    },

    buildPic                  = [[pw_warpgate.png]],
    canGuard                      = true,
    canMove                       = false,
    canPatrol                     = true,
    cantBeTransported             = true,
    category                      = [[FLOAT UNARMED]],
    collisionVolumeOffsets        = [[0 0 0]],
    collisionVolumeScales         = [[70 70 70]],
    collisionVolumeType           = [[ellipsoid]],
    corpse                        = [[DEAD]],

    customParams                  = {
      neededlink     = 20,
      pylonrange     = 50,
      keeptooltip    = [[any string I want]],

      aimposoffset      = [[0 0 0]],
      midposoffset      = [[0 -10 0]],
      modelradius       = [[35]],
      isfakefactory     = [[1]],
      selection_rank    = [[2]],
      shared_energy_gen = 1,
      like_structure    = 1,
      select_show_eco   = 1,
  },

  explodeAs                     = [[ESTOR_BUILDINGEX]],
  floater                       = true,
  footprintX                    = 4,
  footprintZ                    = 4,
  health                        = 2000,
  iconType                      = [[t3hub]],
  levelGround                   = false,
  maneuverleashlength           = [[380]],
  maxSlope                      = 15,
  metalCost                     = Shared.FACTORY_COST,
  noAutoFire                    = false,
  objectName                    = [[pw_techlab.dae]],
  script                        = [[pw_techlab.lua]],
  selfDestructAs                = [[ESTOR_BUILDINGEX]],
  showNanoSpray                 = false,
  sightDistance                 = 380,
  upright                       = true,
  useBuildingGroundDecal        = true,
  workerTime                    = 10,

    featureDefs                   = {

    DEAD = {
      blocking         = false,
      featureDead      = [[HEAP]],
      footprintX       = 4,
      footprintZ       = 4,
      object           = [[pw_techlab_dead.s3o]],
    },


    HEAP = {
      blocking         = false,
      footprintX       = 4,
      footprintZ       = 4,
      object           = [[debris4x4a.s3o]],
    },

  },
  },
}
