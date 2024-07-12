load("@bazel_skylib//lib:paths.bzl", "paths")

def make_binding_gyp(ctx):
    content ="""{{
    \"targets\": [{{
        \"target_name\": \"{}\",
        \"sources\": [{}],
        \"cflags!\": ["{}"],
        \"ccflags_cc!\": ["{}"],
        \"include_dirs\": [ "<!@(node -p \\"require('node-addon-api').include\\")" ]
    }}]
}}""".format(ctx.attr.name,
            ",".join(["\"{}\"".format(src.path) for src in ctx.files.srcs]),
            ",".join([flag for flag in ctx.attr.copts]),
            ",".join([flag for flag in ctx.attr.copts]),)
    binding_gyp = ctx.actions.declare_file("binding.gyp")
    ctx.actions.write(binding_gyp, content)

    return binding_gyp

def _node_binary_impl(ctx):
    inputs_depset = []
    node_modules = ctx.attr.node_modules
    inputs_depset = node_modules[DefaultInfo].files.to_list() + \
        node_modules[OutputGroupInfo]._hidden_top_level_INTERNAL_.to_list()

    node_binary = ctx.actions.declare_file(
        ctx.attr.name + ".node")
    binding_gyp = make_binding_gyp(ctx)
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
        inputs = ctx.files.srcs + inputs_depset + [binding_gyp],
        outputs = [node_binary],
        command = compile_command,
        use_default_shell_env = True,
    )

    return [DefaultInfo(files = depset([node_binary]))]


node_binary = rule(
    implementation = _node_binary_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = [".c", "cc", "cpp"]),
        "copts": attr.string_list(),
        "node_modules": attr.label()
    }
)
