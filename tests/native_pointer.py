"""Send real X11 mouse events for GUI tests, rather than viewport-synthetic input."""
import ctypes
import sys

x11 = ctypes.CDLL("libX11.so.6")
xtest = ctypes.CDLL("libXtst.so.6")
x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
x11.XOpenDisplay.restype = ctypes.c_void_p
x11.XSetInputFocus.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_int, ctypes.c_ulong]
x11.XFlush.argtypes = [ctypes.c_void_p]
x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
xtest.XTestFakeMotionEvent.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_ulong]
xtest.XTestFakeButtonEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
display = x11.XOpenDisplay(None)
if not display:
    raise SystemExit("X11 display required")
if sys.argv[1:] == ["--has-wm"]:
    # Godot's X11 fullscreen flag requires an EWMH window manager. The cloud
    # dummy display can still test desktop coverage and the rendering transform.
    x11.XDefaultRootWindow.argtypes = [ctypes.c_void_p]
    x11.XDefaultRootWindow.restype = ctypes.c_ulong
    x11.XInternAtom.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int]
    x11.XInternAtom.restype = ctypes.c_ulong
    atom = x11.XInternAtom(display, b"_NET_SUPPORTING_WM_CHECK", 1)
    managed = False
    if atom:
        x11.XGetWindowProperty.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_ulong, ctypes.c_long, ctypes.c_long, ctypes.c_int, ctypes.c_ulong, ctypes.POINTER(ctypes.c_ulong), ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_ulong), ctypes.POINTER(ctypes.c_ulong), ctypes.POINTER(ctypes.c_void_p)]
        kind, count, remaining = ctypes.c_ulong(), ctypes.c_ulong(), ctypes.c_ulong()
        fmt, data = ctypes.c_int(), ctypes.c_void_p()
        x11.XGetWindowProperty(display, x11.XDefaultRootWindow(display), atom, 0, 1, 0, 0, ctypes.byref(kind), ctypes.byref(fmt), ctypes.byref(count), ctypes.byref(remaining), ctypes.byref(data))
        managed = count.value > 0
        if data:
            x11.XFree.argtypes = [ctypes.c_void_p]
            x11.XFree(data)
    x11.XCloseDisplay(display)
    raise SystemExit(0 if managed else 2)
window, x, y = map(int, sys.argv[1:4])
x11.XSetInputFocus(display, window, 2, 0)
xtest.XTestFakeMotionEvent(display, -1, x, y, 0)
if len(sys.argv) > 4:
    xtest.XTestFakeButtonEvent(display, 1, int(sys.argv[4]), 0)
x11.XFlush(display)
x11.XCloseDisplay(display)
