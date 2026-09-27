# Tray icon shader

`tray-symbolic.frag` tints neutral pixels with the bar text color. It keeps
colored pixels, including status badges. It does not inspect app names.
Full-color icons bypass this shader.

The compiled shader ships with the plugin. After editing the source, rebuild it
with Qt's shader baker from `qt6-shadertools`:

```sh
/usr/lib/qt6/bin/qsb --glsl '100 es,120,150' --hlsl 50 --msl 12 \
  -o qml/shaders/tray-symbolic.frag.qsb qml/shaders/tray-symbolic.frag
```

Run the pixel tests with a graphics backend. The software scene graph does not
render shaders:

```sh
QT_QPA_PLATFORM=wayland QSG_RHI_BACKEND=opengl \
  /usr/lib/qt6/bin/qmltestrunner -input tests/render
```
