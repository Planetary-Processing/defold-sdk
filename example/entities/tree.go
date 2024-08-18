components {
  id: "entity"
  component: "/pp/entity.script"
}
embedded_components {
  id: "sprite"
  type: "sprite"
  data: "default_animation: \"tree\"\n"
  "material: \"/builtins/materials/sprite.material\"\n"
  "textures {\n"
  "  sampler: \"texture_sampler\"\n"
  "  texture: \"/example/assets/entities.atlas\"\n"
  "}\n"
  ""
  position {
    y: 8.0
  }
  scale {
    z: 0.0625
  }
}
