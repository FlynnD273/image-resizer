extends Control

var original: CompressedTexture2D
var rd: RenderingDevice
var shader: RID

func _ready() -> void:
  _file_open_selected("./kirby_small.png")
  rd = RenderingServer.create_local_rendering_device()
  var shader_file := load("res://gen_grad.comp.glsl")
  var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
  shader = rd.shader_create_from_spirv(shader_spirv)

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
  var grey_pix := grey.get_data()
  var h: int = grey.get_height()
  var w: int = grey.get_width()
  var diff_vals: PackedFloat32Array = PackedFloat32Array()
  diff_vals.resize(w)

  # for x in range(w):
  #   diff_vals[x] = get_pixel(x, 0, w, grey_pix)

  for y in range(h - 1):
    var input_bytes := diff_vals.slice(y * w, (y + 1) * w).to_byte_array()
    var temp := PackedFloat32Array()
    temp.resize(w)
    var output_bytes := temp.to_byte_array()
    var pixel_floats := PackedFloat32Array()
    pixel_floats.resize(w*2)
    var pixel_bytes := grey_pix.slice(y * w, (y + 2) * w)
    for i in range(pixel_floats.size()):
      pixel_floats[i] = pixel_bytes[i] + 0.0
    pixel_bytes = pixel_floats.to_byte_array()

    # Create a storage buffer that can hold our float values.
    # Each float has 4 bytes (32 bit) so 10 x 4 = 40 bytes
    var buffer := rd.storage_buffer_create(input_bytes.size(), input_bytes)
    var uniform := RDUniform.new()
    uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
    uniform.binding = 0 # this needs to match the "binding" in our shader file
    uniform.add_id(buffer)
    var buffer2 := rd.storage_buffer_create(pixel_bytes.size(), pixel_bytes)
    var uniform2 := RDUniform.new()
    uniform2.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
    uniform2.binding = 1 # this needs to match the "binding" in our shader file
    uniform2.add_id(buffer2)
    var buffer3 := rd.storage_buffer_create(output_bytes.size(), output_bytes)
    var uniform3 := RDUniform.new()
    uniform3.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
    uniform3.binding = 2 # this needs to match the "binding" in our shader file
    uniform3.add_id(buffer3)

    var uniform_set := rd.uniform_set_create([uniform, uniform2, uniform3], shader, 0)
    var pipeline := rd.compute_pipeline_create(shader)
    var compute_list := rd.compute_list_begin()
    rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
    rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
    rd.compute_list_dispatch(compute_list, w, 1, 1)
    rd.compute_list_end()
    rd.submit()
    rd.sync()
    output_bytes = rd.buffer_get_data(buffer3)
    var output := output_bytes.to_float32_array()
    diff_vals.append_array(output)

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


  var img: Image = Image.create_from_data(w - 1, h, false, Image.Format.FORMAT_RGB8, new_img)
  var itex: ImageTexture = ImageTexture.create_from_image(img)  
  $GridContainer/ImageDisplay.texture = itex

func _on_grow_button_pressed() -> void:
    pass # Replace with function body.
