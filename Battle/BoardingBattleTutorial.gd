extends "res://Battle/BoardingBattle.gd"

@onready var hint_label : RichTextLabel = $CanvasLayer/HintLabel
@onready var arrow      : Sprite2D      = $Arrow
@onready var manager    : BattleManagerTutorial = $BattleManager
@onready var crew_container : Node2D = $CrewContainer

var step : int = 0
var _advancing : bool = false
var barnaby : CrewMemberNPC = null
var enemy   : EnemyNPC = null

func _ready() -> void:
    await super._ready()
    for c in crew_container.get_children():
        if c is BarnabyCrew:
            barnaby = c
            break
    _show_step()
    set_process(true)

func _process(_delta: float) -> void:
    match step:
        0:
            if barnaby and barnaby.has_boarded and not _advancing:
                _advance_step(1)
        1:
            if barnaby and barnaby.dragging and not _advancing:
                _advance_step(2)
        2:
            if barnaby and enemy and barnaby.targets.has(enemy) and not _advancing:
                _advance_step(3)
        3:
            if enemy and not is_instance_valid(enemy):
                _advance_step(4)

func _show_step() -> void:
    arrow.visible = false
    arrow.target = null
    match step:
        0:
            if barnaby:
                arrow.target = barnaby
                arrow.visible = true
            hint_label.text = "[center]Click Barnaby to deploy him[/center]"
            _fade_in_hint(hint_label)
        1:
            hint_label.text = "[center]Click and drag Barnaby to move him[/center]"
            _fade_in_hint(hint_label)
        2:
            enemy = manager.spawn_single_enemy()
            _toggle_ranges(true)
            if enemy:
                arrow.target = enemy
                arrow.visible = true
            hint_label.text = "[center]Move Barnaby next to the enemy[/center]"
            _fade_in_hint(hint_label)
        3:
            _toggle_ranges(false)
            hint_label.text = "[center]Defeat the enemy[/center]"
            _fade_in_hint(hint_label)
        4:
            hint_label.text = "[center]Tutorial complete![/center]"
            _fade_in_hint(hint_label)

func _toggle_ranges(on: bool) -> void:
    if barnaby and barnaby.has_node("MeleeRange/CollisionShape2D"):
        barnaby.get_node("MeleeRange/CollisionShape2D").visible = on
    if enemy and is_instance_valid(enemy) and enemy.has_node("MeleeRange/CollisionShape2D"):
        enemy.get_node("MeleeRange/CollisionShape2D").visible = on

func _advance_step(next_step: int) -> void:
    _advancing = true
    hint_label.add_theme_color_override("default_color", Color.GREEN)
    await _fade_out_hint(hint_label)
    step = next_step
    _show_step()
    _advancing = false

func _fade_in_hint(label: CanvasItem, duration: float = 0.5) -> void:
    label.visible = true
    label.modulate.a = 0.0
    get_tree().create_tween().tween_property(label, "modulate:a", 1.0, duration)

func _fade_out_hint(label: CanvasItem, duration: float = 0.5) -> void:
    var tw = get_tree().create_tween()
    tw.tween_property(label, "modulate:a", 0.0, duration)
    await tw.finished
    label.hide()

