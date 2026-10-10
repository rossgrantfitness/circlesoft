#!/usr/bin/env python3
"""Shared building blocks for the junkyard rooms (make_junkyard_rooms.py) and Kasp's arena (make_kasp_arena.py), VS-20 and VS-29.

Built on the night market's kit (make_market_rooms.py: materials, Ross's city tiles through the crisp PS2 shader with the
seam-fixed copies, boxes, quads, text). What this adds:

  * `Y`, a room builder for free-camera (orbit) rooms: a plain Node3D level with `Spawns`, a sun and fill, no diorama camera.
  * `cliffs()`: walls from a walkable mask. Give it the rectangles Red can walk on; it fills a band of scrap cliff around them (merged boxes
    of varied height, each with a city-tile face quad on every side that borders the walkable floor) and a full-height collision box for
    each. So a room is "these rectangles" and the walls follow.
  * `tilted_box()`: ramps (a box turned about X or Z with matching collision).
  * `glb()`: an instance of a placeholder model (the Technical Artist's props and arena pieces) with a scale and yaw.
  * `marker()`: a named Marker3D or Node3D under a group node, the way the boss and encounter code will find things.

Coordinates in the junkyard rooms follow docs/maps/junkyard.md: metres, origin at the room's NW floor corner, +X east, +Z south.
"""
import hashlib
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import make_market_rooms as mm  # noqa: E402
from make_market_rooms import M, aim_transform, tile_world_size, yaw_to  # noqa: E402,F401

GAME = mm.GAME
PROPS = "res://art/placeholder/robots/props/"


def unit_hash(*vals):
    h = hashlib.md5(("|".join(str(v) for v in vals)).encode()).hexdigest()
    return int(h[:8], 16) / 0xFFFFFFFF


class Y(M):
    """A free-camera level: plain Node3D root, Spawns, sun and fill, collision. No CameraRig (the ActionRoom's OrbitCamera follows Red)."""

    def __init__(self, room_id, title, w, d, out_sub, min_x=0.0, min_z=0.0):
        super().__init__(room_id, title, w, d)
        self.out_sub = out_sub
        self.min_x, self.min_z = min_x, min_z
        self.groups_made = set()

    def write(self, filename):
        out = os.path.join(GAME, "scenes", "slice", self.out_sub)
        os.makedirs(out, exist_ok=True)
        import make_test_rooms
        saved = make_test_rooms.OUT
        make_test_rooms.OUT = out
        try:
            Room_write(self, filename)
        finally:
            make_test_rooms.OUT = saved

    # ---- extra geometry
    def tilted_box(self, name, cx, cy, cz, sx, sy, sz, mat, rx_deg=0.0, rz_deg=0.0, solid=True):
        """A box of size (sx, sy, sz) at (cx, cy, cz) turned about X by rx_deg and then Z by rz_deg, with matching collision."""
        rx, rz = math.radians(rx_deg), math.radians(rz_deg)
        cxr, sxr, czr, szr = math.cos(rx), math.sin(rx), math.cos(rz), math.sin(rz)
        # R = Rz * Rx ; rows
        r00, r01, r02 = czr, -szr * cxr, szr * sxr
        r10, r11, r12 = szr, czr * cxr, -czr * sxr
        r20, r21, r22 = 0.0, sxr, cxr
        t = "Transform3D(%.5f, %.5f, %.5f, %.5f, %.5f, %.5f, %.5f, %.5f, %.5f, %s, %s, %s)" % (r00, r01, r02, r10, r11, r12, r20, r21, r22, cx, cy, cz)
        mesh = self.box_mesh((sx, sy, sz))
        self.nodes.append('[node name="%s" type="MeshInstance3D" parent="."]\ntransform = %s\nmesh = %s\nsurface_material_override/0 = %s\n' % (name, t, mesh, mat))
        if solid:
            self.nodes.append('[node name="%sShape" type="CollisionShape3D" parent="Collision"]\ntransform = %s\nshape = %s\n' % (name, t, self.box_shape((sx, sy, sz))))

    def glb(self, name, path, x, y, z, yaw=0.0, scale=1.0, parent=".", group=None):
        c, s = math.cos(math.radians(yaw)) * scale, math.sin(math.radians(yaw)) * scale
        t = "Transform3D(%.4f, 0, %.4f, 0, %.4f, 0, %.4f, 0, %.4f, %s, %s, %s)" % (c, s, scale, -s, c, x, y, z)
        head = '[node name="%s" parent="%s" instance=%s' % (name, parent, self.inst(path))
        head += ']'
        if group:
            head = head[:-1] + ' groups=["%s"]]' % group
        self.nodes.append(head + "\ntransform = %s\n" % t)

    def holder(self, name, parent=".", x=0.0, y=0.0, z=0.0):
        self.node(name, "Node3D", parent, (x, y, z))

    def marker(self, name, parent, x, y, z, yaw=0.0, meta=None, kind="Marker3D"):
        extra = ""
        for k, v in (meta or {}).items():
            val = ("true" if v else "false") if isinstance(v, bool) else (v if not isinstance(v, str) else '"%s"' % v)
            extra += "metadata/%s = %s\n" % (k, val)
        self.node(name, kind, parent, (x, y, z), yaw_deg=yaw, extra=extra.rstrip("\n"))

    def aimed_marker(self, name, parent, origin, target):
        """A Marker3D at `origin` looking at `target` (a camera shot: a camera looks down its -Z)."""
        d = (target[0] - origin[0], target[1] - origin[1], target[2] - origin[2])
        self.nodes.append('[node name="%s" type="Marker3D" parent="%s"]\ntransform = %s\n' % (name, parent, aim_transform(origin, d)))

    # ---- level shell
    def shell(self, floor_rects, floor_tile, floor_tint, sun=(1.0, 0.78, 0.55), sun_energy=1.4, sun_dir=(0.22, -0.94, -0.2), fill_energy=1.4,
              ambient=(0.55, 0.58, 0.72)):
        env = self.sub("Environment", "background_mode = 1\nbackground_color = Color(0.09, 0.1, 0.13, 1)\nambient_light_source = 2\n"
                       "ambient_light_color = Color(%s, %s, %s, 1)\nambient_light_energy = 1.0" % ambient)
        self.nodes.append('[node name="%s" type="Node3D"]\n' % self.title)
        self.node("WorldEnvironment", "WorldEnvironment", extra="environment = %s" % env)
        cx = sum((r[0] + r[2]) / 2.0 for r in floor_rects) / len(floor_rects)
        cz = sum((r[1] + r[3]) / 2.0 for r in floor_rects) / len(floor_rects)
        self.node("Sun", "DirectionalLight3D", extra="light_color = Color(%s, %s, %s, 1)\nlight_energy = %s\nshadow_enabled = true\n"
                  "directional_shadow_max_distance = 70.0\ntransform = %s" % (sun[0], sun[1], sun[2], sun_energy, aim_transform((cx, 40, cz), sun_dir)))
        self.node("Fill", "DirectionalLight3D", extra="light_color = Color(0.7, 0.8, 1, 1)\nlight_energy = %s\ntransform = %s" % (
            fill_energy, aim_transform((cx, 40, cz), (-sun_dir[0], -0.7, -sun_dir[2]))))
        self.node("Collision", "StaticBody3D")
        tint = tuple(min(c * 1.8, 1.9) for c in floor_tint)
        for i, (x0, z0, x1, z1) in enumerate(floor_rects):
            w, d = x1 - x0, z1 - z0
            tw, th = tile_world_size(floor_tile)
            self.plane("Floor%d" % i, (x0 + x1) / 2.0, 0, (z0 + z1) / 2.0, w, d, self.tile(floor_tile, (w / tw, d / th), tint, offset=(x0 / tw, z0 / th)))
            self.collide("FloorShape%d" % i, (x0 + x1) / 2.0, -0.1, (z0 + z1) / 2.0, w, 0.2, d)
        self.node("Spawns", "Node3D")

    def spawn(self, name, x, z, face=(0, 1), y=0.0):
        self.node(name, "Marker3D", "Spawns", (x, y, z), yaw_deg=yaw_to(*face))

    # ---- scrap cliffs from a walkable mask
    def cliffs(self, walk_rects, bounds, cell=2.0, band=3, tiles=("rust_streaked_plate_tall", "rust_riveted_plates_tall", "steel_plate_riveted_grey"),
               hmin=11.0, hmax=21.0, seed="", tint=(0.8, 0.72, 0.68), holes=()):
        """Fills non-walkable cells within `band` cells of the walkable rectangles with merged cliff boxes (full collision) and a tile quad on
        every side that faces the floor. `bounds` = (x0, z0, x1, z1) of the area considered. `holes`: rectangles that are NOT walkable but
        also get no cliff (a pit)."""
        bx0, bz0, bx1, bz1 = bounds
        nx, nz = int(round((bx1 - bx0) / cell)), int(round((bz1 - bz0) / cell))

        def centre(ix, iz):
            return bx0 + (ix + 0.5) * cell, bz0 + (iz + 0.5) * cell

        def inside(rects, x, z):
            return any(r[0] <= x <= r[2] and r[1] <= z <= r[3] for r in rects)
        walk = [[inside(walk_rects, *centre(ix, iz)) for ix in range(nx)] for iz in range(nz)]
        hole = [[inside(holes, *centre(ix, iz)) for ix in range(nx)] for iz in range(nz)] if holes else None
        wall = [[False] * nx for _ in range(nz)]
        for iz in range(nz):
            for ix in range(nx):
                if walk[iz][ix] or (hole and hole[iz][ix]):
                    continue
                near = False
                for dz in range(-band, band + 1):
                    for dx in range(-band, band + 1):
                        jz, jx = iz + dz, ix + dx
                        if 0 <= jz < nz and 0 <= jx < nx and walk[jz][jx]:
                            near = True
                if near:
                    wall[iz][ix] = True

        def height(ix, iz):
            return round(hmin + (hmax - hmin) * unit_hash(seed, ix // 3, iz // 3), 1)
        # merge: runs along x with equal height, then identical consecutive rows
        rows = []
        for iz in range(nz):
            runs, ix = [], 0
            while ix < nx:
                if wall[iz][ix]:
                    h = height(ix, iz)
                    start = ix
                    while ix < nx and wall[iz][ix] and height(ix, iz) == h:
                        ix += 1
                    runs.append((start, ix, h))
                else:
                    ix += 1
            rows.append(runs)
        boxes, open_boxes = [], {}
        for iz in range(nz + 1):
            current = {(a, b, h) for (a, b, h) in rows[iz]} if iz < nz else set()
            for key in list(open_boxes):
                if key not in current:
                    boxes.append((key[0], open_boxes[key], key[1], iz, key[2]))
                    del open_boxes[key]
            for key in current:
                if key not in open_boxes:
                    open_boxes[key] = iz
        # open_boxes entries were stored by (a, b, h) -> start row; boxes tuples are (a, start_row, b, end_row, h)
        count = 0
        mat = self.lit((0.32 * tint[0], 0.27 * tint[1], 0.24 * tint[2]))
        for (a, z_start, b, z_end, h) in boxes:
            x0, x1 = bx0 + a * cell, bx0 + b * cell
            z0, z1 = bz0 + z_start * cell, bz0 + z_end * cell
            name = "Cliff%d" % count
            count += 1
            self.box(name, (x0 + x1) / 2.0, h / 2.0, (z0 + z1) / 2.0, x1 - x0, h, z1 - z0, mat, solid=True, parent="Cliffs")
            tile = tiles[int(unit_hash(seed, a, z_start, "t") * len(tiles)) % len(tiles)]
            tw, th = tile_world_size(tile)
            # faces that border walkable floor
            def side_walk(cells):
                return any(0 <= jz < nz and 0 <= jx < nx and walk[jz][jx] for jx, jz in cells)
            faces = []
            if side_walk([(ix, z_start - 1) for ix in range(a, b)]):
                faces.append(("N", x0, x1, z0))       # the box's north face, facing -Z
            if side_walk([(ix, z_end) for ix in range(a, b)]):
                faces.append(("S", x0, x1, z1))
            if side_walk([(a - 1, iz) for iz in range(z_start, z_end)]):
                faces.append(("W", z0, z1, x0))
            if side_walk([(b, iz) for iz in range(z_start, z_end)]):
                faces.append(("E", z0, z1, x1))
            for side, lo, hi, at in faces:
                length = hi - lo
                fm = self.tile(tile, (length / tw, h / th), tint, offset=(lo / tw, 0.0))
                if side == "S":
                    self.quad("%sFaceS" % name, (lo + hi) / 2.0, h / 2.0, at + 0.02, length, h, fm, parent="Cliffs")
                elif side == "N":
                    self.quad("%sFaceN" % name, (lo + hi) / 2.0, h / 2.0, at - 0.02, length, h, fm, yaw=180, parent="Cliffs")
                elif side == "E":
                    self.quad("%sFaceE" % name, at + 0.02, h / 2.0, (lo + hi) / 2.0, length, h, fm, yaw=90, parent="Cliffs")
                else:
                    self.quad("%sFaceW" % name, at - 0.02, h / 2.0, (lo + hi) / 2.0, length, h, fm, yaw=-90, parent="Cliffs")
        return count


def Room_write(room, filename):
    """The base Room.write (M.write wraps it for the market's folder; the yards pick their own)."""
    from make_test_rooms import Room
    Room.write(room, filename)
