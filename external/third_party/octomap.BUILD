cc_library(
  name = 'octomap',
  visibility = ["//visibility:public"],
  srcs = glob([
    'octomap/src/**/*.cpp',
  ]),
  hdrs = glob([
    'octomap/src/testing/testing.h',
    'octomap/include/**/*.h',
    'octomap/include/**/*.hxx',
  ]),
  includes = [
    'octomap/include',
    'octomap/include/octomap',
  ],
  copts = [
    '-Wno-unused-parameter',
  ],
)
