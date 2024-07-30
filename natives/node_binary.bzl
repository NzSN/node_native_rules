load("@bazel_skylib//lib:paths.bzl", "paths")

def make_binding_gyp(ctx, includes):
    content ="""{{
    \"targets\": [{{
        \"target_name\": \"{}\",
        \"sources\": [{}],
        \"cflags!\": [],
        \"ccflags_cc!\": {},
        \"include_dirs\": {},
    }}]
}}""".format(ctx.attr.name,
            ",".join(["\"{}\"".format(src.path) for src in ctx.files.srcs]),
             ctx.attr.copts,
             ctx.attr.include_dirs + ["external/abseil-cpp~"] + [ "<!@(node -p \"require('node-addon-api').include\")" ] + includes,)
    binding_gyp = ctx.actions.declare_file("binding.gyp")
    ctx.actions.write(binding_gyp, content)

    return binding_gyp

def _node_binary_impl(ctx):
    inputs_depset = []
    node_modules = ctx.attr.node_modules
    inputs_depset = node_modules[DefaultInfo].files.to_list() + \
        node_modules[OutputGroupInfo]._hidden_top_level_INTERNAL_.to_list()

    # Collect transitive sources and headers
    includes = []
    deps = []
    for dep in ctx.attr.deps:
      if CcInfo in dep:
        deps += dep[CcInfo].compilation_context.headers.to_list() + dep[DefaultInfo].files.to_list()
        includes += dep[CcInfo].compilation_context.includes.to_list()
      if OutputGroupInfo in dep:
          if "compilation_prerequisites_INTERNAL_" in dep[OutputGroupInfo]:
              print(dep[CcInfo].compilation_context)
              deps += dep[OutputGroupInfo].compilation_prerequisites_INTERNAL_.to_list()


    node_binary = ctx.actions.declare_file(
        ctx.attr.name + ".node")
    binding_gyp = make_binding_gyp(ctx, includes)
    node_module_path = node_modules[DefaultInfo].files.to_list()[0].path
    node_module_path = node_module_path[0:node_module_path.rfind("node_modules")+12]

    compile_command = """
    ln -s {} node_modules
    mv {} .;
    ./node_modules/node-gyp/bin/node-gyp.js configure
    ./node_modules/node-gyp/bin/node-gyp.js build
    cp build/Release/{}.node {};
    """.format(node_module_path,
               binding_gyp.path,
               ctx.attr.name,
               node_binary.path)

    ctx.actions.run_shell(
        inputs = ctx.files.srcs + inputs_depset + [binding_gyp] + deps,
        outputs = [node_binary],
        command = compile_command,
        use_default_shell_env = True,
    )

    return [DefaultInfo(files = depset([node_binary]))]


node_binary = rule(
    implementation = _node_binary_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = [".c", ".cc", ".cpp", ".h", ".so"]),
        "copts": attr.string_list(),
        "node_modules": attr.label(),
        "include_dirs": attr.string_list(),
        "deps": attr.label_list(),
    }
)
