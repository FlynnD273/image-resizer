#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 2, local_size_y = 1, local_size_z = 1) in;

// A binding to the buffer we create in our script
layout(set = 0, binding = 0, std430) restrict buffer InputBuffer {
    float data[];
}
input_buf;

layout(set = 0, binding = 1, std430) restrict buffer PixelBuffer {
    float data[];
}
pixel_buf;

layout(set = 0, binding = 2, std430) restrict buffer OutputBuffer {
    float data[];
}
output_buf;

// The code we want to execute in each invocation
void main() {
    // gl_GlobalInvocationID.x uniquely identifies this invocation across all work groups
    int width = output_buf.data.length();
    uint x = gl_GlobalInvocationID.x;
    float middle = input_buf.data[x] + abs(pixel_buf.data[x + width] - pixel_buf.data[x]);
    float right = middle;
    float left = middle;

    right = x != width - 1 ? input_buf.data[x + 1] + abs(pixel_buf.data[x + width] - pixel_buf.data[x + 1]) : right;
    left = x != 0 ? input_buf.data[x - 1] + abs(pixel_buf.data[x + width] - pixel_buf.data[x - 1]) : left;

    output_buf.data[x] = min(left, min(middle, right));
}
