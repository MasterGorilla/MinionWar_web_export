extends Resource

class_name Weapon_Resource

@export var weapon_name: String
@export var Melee_Only: bool = false
@export var Blade: bool = false

@export var Activate_Anim: String
@export var Shoot_Anim: String
@export var Reload_Anim: String
@export var Deactivate_Anim: String
@export var Out_Of_Ammo_Anim: String
@export var Melee_Anim: String
@export var Scope_Anim: String

@export var Current_Ammo: int #Obvious. The gun's current ammo.
@export var Reload_Ammo: int #The ammo the gun has to reload from.
@export var Magazine: int #The size of the magazine. The max the gun can reload.
@export var Max_Ammo: int #The max size of the reserve.

@export var RecoilAmmount: float = 0

@export var constant_dot: bool = true
@export var Dot_Color: Color = Color.WHITE

@export var Auto_Fire: bool
@export var Scopable: bool
@export var Scope_Factor: float
@export var Background: bool = false #scope background
@export var constant_circle: bool = false
@export var Circle_Color: Color = Color.WHITE
@export var Circle_Radius: float
@export var constant_cross: bool
@export var Cross_Color: Color = Color.WHITE
@export var Cross_Outer_Radius: float
@export var Cross_Inner_Radius: float
#@export var Knife: bool

@export_flags("hitscan", "projectile") var Type

@export var Weapon_Range: float
@export var Melee_Range: float = 1.5
@export var Damage: float
@export var Melee_Damage: float = 1.5

@export var Projectile_Scene: PackedScene
@export var Projectile_Velocity: float
@export var Projectile_Scale: float = 1

@export var Weapon_Drop: PackedScene
