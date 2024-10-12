extends Control

var original: CompressedTexture2D

func _ready() -> void:
  _file_open_selected("./kirby_small.png")

func _on_open_button_pressed() -> void:
  var f := FileDialog.new()
  f.file_mode = FileDialog.FILE_MODE_OPEN_FILE
  f.use_native_dialog = true
  f.popup()
  f.file_selected.connect(_file_open_selected)

func _file_open_selected(path: String) -> void:
  original = load(path)
  $GridContainer/ImageDisplay.texture = original

func _on_save_button_pressed() -> void:
  var f := FileDialog.new()
  f.file_mode = FileDialog.FILE_MODE_SAVE_FILE
  f.add_filter("*.png", "png")
  f.use_native_dialog = true
  f.popup()
  f.file_selected.connect(_file_save_selected)

func _file_save_selected(path: String) -> void:
  $GridContainer/ImageDisplay.texture.get_image().save_png(path)

func get_pindex(x: int, y: int, w: int) -> int:
  return x + y * w

func get_pixel(x: int, y: int, w: int, pixels: PackedByteArray) -> int:
  return pixels[get_pindex(x, y, w)]

func get_val(x: int, y: int, w: int, pixels: PackedFloat32Array) -> float:
  return pixels[get_pindex(x, y, w)]

func get_color_pixel(x, y, w, pixels: PackedByteArray) -> Vector3i:
  return Vector3i(pixels[get_pindex(x, y, w) * 3], pixels[get_pindex(x, y, w) * 3 + 1], pixels[get_pindex(x, y, w) * 3 + 2])

func _on_shrink_button_pressed() -> void:
  var color: Image = $GridContainer/ImageDisplay.texture.get_image()
  color.convert(Image.Format.FORMAT_RGB8)
  var color_pixels: PackedByteArray = $GridContainer/ImageDisplay.texture.get_image().get_data()
  var grey: Image = $GridContainer/ImageDisplay.texture.get_image()
  grey.convert(Image.Format.FORMAT_L8)
  var pix := grey.get_data()
  var h: int = grey.get_height()
  var w: int = grey.get_width()
  var diff_vals: PackedFloat32Array = PackedFloat32Array()
  diff_vals.resize(w*h)

  var max_val: float = 0
  for y in range(h):
    for x in range(w):
      if y == 0:
        var pxl: int = get_pixel(x, y, w, pix)
        diff_vals[get_pindex(x, y, w)] = pxl
        if max_val < pxl:
          max_val = pxl
        continue

      var curr: float = get_pixel(x, y, w, pix)
      var left: float = 1024
      var middle: float = 1024
      var right: float = 1024

      if x != 0:
        left = get_val(x - 1, y-1, w, diff_vals) + abs(curr - get_pixel(x - 1, y - 1, w, pix))
      if x != w - 1:
        right = get_val(x + 1, y-1, w, diff_vals) + abs(curr - get_pixel(x + 1, y - 1, w, pix))
      middle = get_val(x, y-1, w, diff_vals) + abs(curr - get_pixel(x, y - 1, w, pix))

      var min_diff: float = min(left, middle, right)
      diff_vals[get_pindex(x, y, w)] = min_diff
      if max_val < min_diff:
        max_val = min_diff

  var seam: Array[int] = []
  seam.resize(h)
  var min_val: float = get_val(0, h - 1, w, diff_vals)
  var min_x: int = 0
  for x in range(1, w):
    var val: float = get_val(x, h - 1, w, diff_vals)
    if val < min_val:
      min_val = val
      min_x = x

  seam[-1] = min_x

  for y in range(h - 2, -1, -1):
    var x: int = seam[y + 1]
    var middle: float = get_val(x, y - 1, w, diff_vals)
    var left: float = middle
    if x != 0:
      left = get_val(x - 1, y - 1, w, diff_vals)
    var right: float = middle
    if x != w - 1:
      right = get_val(x + 1, y - 1, w, diff_vals)
    min_val = min(left, middle, right)

    if min_val == left:
      seam[y] = x - 1
    elif min_val == middle:
      seam[y] = x
    elif min_val == right:
      seam[y] = x + 1

  var new_img: PackedByteArray = PackedByteArray()
  new_img.resize((w - 1)*h * 3)
  for y in range(h):
    for x in range(w - 1):
      var col: Vector3i
      if x < seam[y]:
        col = get_color_pixel(x, y, w, color_pixels)
      else:
        col = get_color_pixel(x + 1, y, w, color_pixels)
      var idx: int = get_pindex(x, y, w - 1) * 3
      new_img[idx] = col.x
      new_img[idx + 1] = col.y
      new_img[idx + 2] = col.z

  var debug: PackedByteArray = PackedByteArray()
  debug.resize(w*h)
  for x in range(w):
    for y in range(h):
      var i: int = get_pindex(x, y, w)
      if x == seam[y]:
        debug[i] = 255
      else:
        debug[i] = diff_vals[i] * 255 / max_val


  var img: Image = Image.create_from_data(w - 1, h, false, Image.Format.FORMAT_RGB8, new_img)
  var itex: ImageTexture = ImageTexture.create_from_image(img)  
  $GridContainer/ImageDisplay.texture = itex

  var d: Image = Image.create_from_data(w, h, false, Image.Format.FORMAT_L8, debug)
  var dtex: ImageTexture = ImageTexture.create_from_image(d)  
  $GridContainer/DebugDisplay.texture = dtex

func _on_grow_button_pressed() -> void:
    pass # Replace with function body.
