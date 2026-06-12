// Single full-screen triangle from the vertex id, clipped to viewport.
float4 main(uint vid : SV_VertexID) : SV_Position {
    float4 position;
    position.x = (vid == 2) ? 3.0 : -1.0;
    position.y = (vid == 0) ? -3.0 : 1.0;
    position.z = 1.0;
    position.w = 1.0;
    return position;
}
