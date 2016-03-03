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
#include "sky/shell/platform/linux/platform_view_linux.h"
#include "sky/shell/testing/testing.h"
#include "ui/gl/gl_surface.h"

#include "GLFW/glfw3.h"

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

  CHECK(gfx::GLSurface::InitializeOneOff());
  sky::shell::Shell::InitStandalone();

  /*
  if (command_line.HasSwitch(sky::shell::switches::kNonInteractive)) {
    if (!sky::shell::InitForTesting()) {
      return 1;
    }
  }
  */

  if (!glfwInit()) {
    return 1;
  }

  GLFWwindow *window = glfwCreateWindow(640, 480, "Flutter", NULL, NULL);
  if (window == NULL) {
    glfwTerminate();
    return 1;
  }

  auto shell_view = new sky::shell::ShellView(sky::shell::Shell::Shared());
  auto platform_view = static_cast<sky::shell::PlatformViewLinux *>(shell_view->view());
  platform_view->SurfaceCreated(window);

  message_loop.Run();
  return 0;
}
