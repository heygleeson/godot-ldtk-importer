# Classes

`ldtk-importer` parses the LDTK file and extracts *only the most useful information* from each definition and instance, ignoring editor-only values or data deemed unimportant to creating the imported scene.

The goal is to make it easy for users to access the most important data that can then be used in writing post-import scripts.

## LDTKWorld

| Property | Type | Description |
| --- | --- | --- |
| **`rect`** | **`Rect2i`** | The bounding box covering all levels |

## LDTKWorldLayer

> NOTE: Only visible when **Separate World Layers** is selected.

| Property | Type | Description |
| --- | --- | --- |
| **`depth`** | **`int`** | The worldDepth layer (i.e. z-index) used by child levels ||

## LDTKLevel

| Property | Type | Description |
| --- | --- | --- |
| **`size`** | **`Vector2i`** | Size of the level, in pixels. |
| **`fields`** | **`Dictionary`** | Imported fields used by the Level. |
| **`neighours`** | **`Array`** | List of level neighbours. |
| **`bg_color`** | **`Color`** | Background color used by the Level. |

## LDTKEntityLayer

| Property | Type | Description |
| --- | --- | --- |
| **`definition`** | **`Dictionary`** | Layer definition. |
| **`entities`** | **`Array`** | List of entity instances belonging to this layer. |

### Layer.definition

| Property | Type | Description |
| --- | --- | --- |
| **`uid`** | **`int`** | Unique layer ID  |
| **`type`** | **`String`** | Layer type (e.g. "Entities", "AutoLayer", etc.) |
| **`identifier`** | **`String`** | Layer name |
| **`gridSize`** | **`int`** | Size of the layer grid, in pixels |
| **`offset`** | **`Vector2i`** | Layer offset, in pixels |
| **`parallax`** | **`Vector2`** | Layer parallax factor |
| **`parallaxScaling`** | **`bool`** | If `true`, layer will scale up/down accordingly. |
| **`intGridValues`** | **`Array`** | An array that defines extra optional info (only used by IntGrid layers) |

## LDTKEntity

> NOTE: Can be found in `LDTKEntityLayer.entities`, as well as `LDTKEntity` nodes when **Use Entity Placeholders** is selected.

| Property | Type | Description |
| --- | --- | --- |
| **`iid`** | **`String`** | Unique instance id (used by LDtk for EntityRefs) |
| **`identifier`** | **`String`** | Entity name (as used by LDtk) |
| **`fields`** | **`Dictionary`** | Imported fields used by the Entity |
| **`pivot`** | **`Vector2`** | Pivot alignment of the Entity |
| **`size`** | **`Vector2i`** | Parsed size of the Entity (accounts for resizing) |
| **`smart_color`** | **`Color`** | Instance color (influenced by field values) |
| **`definition`** | **`Dictionary`** | Entity Definition |

### Entity.definition

| Property | Type | Description |
| --- | --- | --- |
| **`identifier`** | **`String`** | Entity name (as used by LDtk) |
| **`color`** | **`Color`** | Base Entity color |
| **`renderMode`** | **`String`** | "Ellipse", "Rect", "Cross", etc. (used by placeholders) |
| **`hollow`** | **`bool`** | Used by placeholders |
| **`tags`** | **`Array`** | Tags associated with this Entity definition |
| **`field_defs`** | **`Dictionary`** | Used by placeholders |