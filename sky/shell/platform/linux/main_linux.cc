// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "base/at_exit.h"
#include "base/basictypes.h"
#include "base/bind.h"
#include "base/command_line.h"
#include "base/logging.h"
#include "base/message_loop/message_loop.h"
#include "base/trace_event/trace_event.h"
#include "mojo/edk/embedder/embedder.h"
#include "mojo/edk/embedder/simple_platform_support.h"
#include "sky/shell/shell.h"
#include "sky/shell/switches.h"
#include "sky/shell/testing/testing.h"
#include "ui/gl/gl_surface.h"

#if defined(USE_GLFW)
#include "sky/shell/platform/linux/platform_view_linux.h"
#include "GLFW/glfw3.h"
#endif

int main(int argc, const char* argv[]) {
  base::AtExitManager exit_manager;
  base::CommandLine::Init(argc, argv);

  base::CommandLine& command_line = *base::CommandLine::ForCurrentProcess();

  if (command_line.HasSwitch(sky::shell::switches::kHelp)) {
    sky::shell::switches::PrintUsage("sky_shell");
    return 0;
  }

  base::MessageLoop message_loop;

  mojo::embedder::Init(std::unique_ptr<mojo::embedder::PlatformSupport>(
      new mojo::embedder::SimplePlatformSupport()));

  sky::shell::Shell::InitStandalone();

  if (command_line.HasSwitch(sky::shell::switches::kNonInteractive)) {
    if (!sky::shell::InitForTesting()) {
      return 1;
    }
  }

#if defined(USE_GLFW)
  if (!glfwInit()) {
    return 1;
  }

  GLFWwindow *window = glfwCreateWindow(640, 480, "Flutter", NULL, NULL);
  if (window == NULL) {
    glfwTerminate();
    return 1;
  }

  glfwMakeContextCurrent(window);
  CHECK(gfx::GLSurface::InitializeOneOff());
  glfwMakeContextCurrent(NULL);

  auto shell_view = new sky::shell::ShellView(sky::shell::Shell::Shared());
  auto platform_view =
      static_cast<sky::shell::PlatformViewLinux *>(shell_view->view());
  platform_view->SurfaceCreated(window);

  sky::SkyEnginePtr sky_engine;
  platform_view->ConnectToEngine(mojo::GetProxy(&sky_engine));
  auto metrics = sky::ViewportMetrics::New();
  metrics->physical_width = 640;
  metrics->physical_height = 480;
  metrics->device_pixel_ratio = 1.0;
  sky_engine->OnViewportMetricsChanged(metrics.Pass());


  auto args = command_line.GetArgs();
  sky_engine->RunFromFile(args[0],
      command_line.GetSwitchValueASCII(sky::shell::switches::kPackageRoot));
#endif

  message_loop.Run();
  return 0;
}
