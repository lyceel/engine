// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "sky/shell/platform/mac/platform_mac.h"

#include <Foundation/Foundation.h>

#include <asl.h>
#include "base/at_exit.h"
#include "base/command_line.h"
#include "base/i18n/icu_util.h"
#include "base/lazy_instance.h"
#include "base/logging.h"
#include "base/mac/scoped_nsautorelease_pool.h"
#include "base/message_loop/message_loop.h"
#include "mojo/edk/embedder/embedder.h"
#include "mojo/edk/embedder/simple_platform_support.h"
#include "sky/shell/shell.h"
#include "sky/shell/switches.h"
#include "sky/shell/tracing_controller.h"
#include "sky/shell/ui_delegate.h"
#include "ui/gl/gl_surface.h"
#include "base/trace_event/trace_event.h"

namespace sky {
namespace shell {

static void InitializeLogging() {
  logging::LoggingSettings settings;
  settings.logging_dest = logging::LOG_TO_SYSTEM_DEBUG_LOG;
  logging::InitLogging(settings);
  logging::SetLogItems(false,   // Process ID
                       false,   // Thread ID
                       false,   // Timestamp
                       false);  // Tick count
}

static void RedirectIOConnectionsToSyslog() {
#if TARGET_OS_IPHONE
  asl_log_descriptor(NULL, NULL, ASL_LEVEL_INFO, STDOUT_FILENO,
                     ASL_LOG_DESCRIPTOR_WRITE);
  asl_log_descriptor(NULL, NULL, ASL_LEVEL_NOTICE, STDERR_FILENO,
                     ASL_LOG_DESCRIPTOR_WRITE);
#endif
}

int PlatformMacMain(int argc,
                    const char* argv[],
                    PlatformMacMainCallback callback) {
  base::mac::ScopedNSAutoreleasePool pool;

  base::PlatformThread::SetName("platform_main");

  base::AtExitManager exit_manager;

  RedirectIOConnectionsToSyslog();

  bool result = false;

  result = base::CommandLine::Init(argc, argv);
  DLOG_ASSERT(result);

  InitializeLogging();

  base::CommandLine& command_line = *base::CommandLine::ForCurrentProcess();
  if (command_line.HasSwitch(sky::shell::switches::kTraceStartup)) {
    // Usually, all tracing within flutter is managed via the tracing controller
    // The tracing controller is accessed via the shell instance. This means
    // that tracing can only be enabled once that instance is created. Traces
    // early in startup are lost. This enables tracing only in base manually
    // till the tracing controller takes over.
    sky::shell::TracingController::StartBaseTracing();
  }

  // This is about as early as tracing of any kind can start. Add an instant
  // marker that can be used as a reference for startup.
  TRACE_EVENT_INSTANT0("flutter", "main", TRACE_EVENT_SCOPE_PROCESS);

  std::unique_ptr<base::MessageLoopForUI> message_loop(
      new base::MessageLoopForUI());

#if TARGET_OS_IPHONE
  // One cannot start the message loop on the platform main thread. Instead,
  // we attach to the CFRunLoop
  message_loop->Attach();
#endif

  mojo::embedder::Init(mojo::embedder::CreateSimplePlatformSupport());

  CHECK(gfx::GLSurface::InitializeOneOff());
  sky::shell::Shell::InitStandalone();

  result = callback();

#if !TARGET_OS_IPHONE
  if (result == EXIT_SUCCESS) {
    message_loop->QuitNow();
  }
#endif

  return result;
}

static bool FlagsValidForCommandLineLaunch(const std::string& dart_main,
                                           const std::string& package_root,
                                           const std::string& bundle) {
  if (dart_main.size() == 0 || package_root.size() == 0 || bundle.size() == 0) {
    return false;
  }

  // Ensure that the paths exists. This catches cases where the user has
  // successfully launched the application from the tooling but has since moved
  // the source files on disk and is launching again directly.

  NSFileManager* manager = [NSFileManager defaultManager];

  if (![manager fileExistsAtPath:@(dart_main.c_str())]) {
    return false;
  }

  if (![manager fileExistsAtPath:@(package_root.c_str())]) {
    return false;
  }

  if (![manager fileExistsAtPath:@(bundle.c_str())]) {
    return false;
  }

  return true;
}

static std::string ResolveCommandLineLaunchFlag(const char* name) {
  auto command_line = *base::CommandLine::ForCurrentProcess();

  if (command_line.HasSwitch(name)) {
    return command_line.GetSwitchValueASCII(name);
  }

  const char* saved_default =
      [[NSUserDefaults standardUserDefaults] stringForKey:@(name)].UTF8String;

  if (saved_default != NULL) {
    return saved_default;
  }

  return "";
}

bool AttemptLaunchFromCommandLineSwitches(sky::SkyEnginePtr& engine) {
  base::mac::ScopedNSAutoreleasePool pool;

  using namespace sky::shell::switches;

  NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];

  auto command_line = *base::CommandLine::ForCurrentProcess();

  if (command_line.HasSwitch(kMainDartFile) ||
      command_line.HasSwitch(kPackageRoot) || command_line.HasSwitch(kFLX)) {
    // The main dart file, flx bundle and the package root must be specified in
    // one go. We dont want to end up in a situation where we take one value
    // from the command line and the others from user defaults. In case, any
    // new flags are specified, forget about all the old ones.
    [defaults removeObjectForKey:@(kMainDartFile)];
    [defaults removeObjectForKey:@(kPackageRoot)];
    [defaults removeObjectForKey:@(kFLX)];

    [defaults synchronize];
  }

  std::string dart_main = ResolveCommandLineLaunchFlag(kMainDartFile);
  std::string package_root = ResolveCommandLineLaunchFlag(kPackageRoot);
  std::string bundle = ResolveCommandLineLaunchFlag(kFLX);

  if (!FlagsValidForCommandLineLaunch(dart_main, package_root, bundle)) {
    return false;
  }

  // Save the newly resolved dart main file and the package root to user
  // defaults so that the next time the user launches the application in the
  // simulator without the tooling, the application boots up.
  [defaults setObject:@(dart_main.c_str()) forKey:@(kMainDartFile)];
  [defaults setObject:@(package_root.c_str()) forKey:@(kPackageRoot)];
  [defaults setObject:@(bundle.c_str()) forKey:@(kFLX)];

  [defaults synchronize];

  // Finally launch with the newly resolved arguments.
  engine->RunFromFile(dart_main, package_root, bundle);
  return true;
}

}  // namespace shell
}  // namespace sky
