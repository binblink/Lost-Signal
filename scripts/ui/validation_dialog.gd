extends PanelContainer

signal closed

const ERROR_COLOR   := "e05252"
const WARNING_COLOR := "e0a040"
const OK_COLOR      := "52c07a"

@onready var _title:    Label         = %Title
@onready var _body:     RichTextLabel = %Body
@onready var _copy_btn: Button        = %CopyButton
@onready var _close_btn: Button       = %CloseButton

var _plain_text: String = ""


func _ready() -> void:
	_copy_btn.pressed.connect(_on_copy_pressed)
	_close_btn.pressed.connect(_on_close_pressed)


func open(report: Dictionary) -> void:
	var errors:   Array = report.get("errors", [])
	var warnings: Array = report.get("warnings", [])
	_title.text   = _build_title(errors, warnings)
	_body.text    = _build_bbcode(errors, warnings)
	_plain_text   = _build_plain_text(errors, warnings)
	_copy_btn.visible = not (errors.is_empty() and warnings.is_empty())
	visible = true


func _build_title(errors: Array, warnings: Array) -> String:
	if errors.is_empty() and warnings.is_empty():
		return tr("VALID_OK")
	var parts: Array = []
	if errors.size() > 0:
		parts.append(tr("VALID_COUNT_ERRORS") % errors.size())
	if warnings.size() > 0:
		parts.append(tr("VALID_COUNT_WARNINGS") % warnings.size())
	return " — ".join(parts)


func _build_bbcode(errors: Array, warnings: Array) -> String:
	if errors.is_empty() and warnings.is_empty():
		return "[color=#%s]%s[/color]" % [OK_COLOR, tr("VALID_OK_BODY")]
	var lines: Array = []
	for err in errors:
		lines.append("[color=#%s]✕  %s[/color]" % [ERROR_COLOR, err])
	if not errors.is_empty() and not warnings.is_empty():
		lines.append("")
	for warn in warnings:
		lines.append("[color=#%s]⚠  %s[/color]" % [WARNING_COLOR, warn])
	return "\n".join(lines)


func _build_plain_text(errors: Array, warnings: Array) -> String:
	var lines: Array = []
	for err in errors:
		lines.append("✕ " + err)
	for warn in warnings:
		lines.append("⚠ " + warn)
	return "\n".join(lines)


func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(_plain_text)


func _on_close_pressed() -> void:
	visible = false
	closed.emit()
