extends SceneTree

func _init():
    var props = root.get_property_list()
    for p in props:
        if "layout" in p.name.to_lower():
            print("PROP: ", p.name)
    quit()
