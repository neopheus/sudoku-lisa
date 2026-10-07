#!/usr/bin/env python3
"""Generate the dependency-free Xcode project; Xcode 16+ syncs App automatically."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = '''// !$*UTF8*$!
{
 archiveVersion = 1;
 classes = {};
 objectVersion = 77;
 objects = {
  A00000000000000000000001 = {isa = PBXProject; attributes = {BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 2700; TargetAttributes = {A00000000000000000000002 = {CreatedOnToolsVersion = 27.0; ProvisioningStyle = Automatic; }; }; }; buildConfigurationList = A00000000000000000000010; compatibilityVersion = "Xcode 16.0"; developmentRegion = fr; hasScannedForEncodings = 0; knownRegions = (fr, en, ru, de, es, Base); mainGroup = A00000000000000000000003; minimizedProjectReferenceProxies = 1; packageReferences = (A00000000000000000000020); preferredProjectObjectVersion = 77; productRefGroup = A00000000000000000000004; projectDirPath = ""; projectRoot = ""; targets = (A00000000000000000000002); };
  A00000000000000000000002 = {isa = PBXNativeTarget; buildConfigurationList = A00000000000000000000011; buildPhases = (A00000000000000000000007, A00000000000000000000008, A00000000000000000000009); buildRules = (); dependencies = (); fileSystemSynchronizedGroups = (A00000000000000000000005); name = SudokuLisa; packageProductDependencies = (A00000000000000000000021); productName = SudokuLisa; productReference = A00000000000000000000006; productType = "com.apple.product-type.application"; };
  A00000000000000000000003 = {isa = PBXGroup; children = (A00000000000000000000005, A00000000000000000000004); sourceTree = "<group>"; };
  A00000000000000000000004 = {isa = PBXGroup; children = (A00000000000000000000006); name = Products; sourceTree = "<group>"; };
  A00000000000000000000005 = {isa = PBXFileSystemSynchronizedRootGroup; exceptions = (A00000000000000000000023); explicitFileTypes = {}; explicitFolders = (); path = App; sourceTree = "<group>"; };
  A00000000000000000000006 = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = SudokuLisa.app; sourceTree = BUILT_PRODUCTS_DIR; };
  A00000000000000000000007 = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
  A00000000000000000000008 = {isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (A00000000000000000000022); runOnlyForDeploymentPostprocessing = 0; };
  A00000000000000000000009 = {isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
  A00000000000000000000010 = {isa = XCConfigurationList; buildConfigurations = (A00000000000000000000012, A00000000000000000000013); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };
  A00000000000000000000011 = {isa = XCConfigurationList; buildConfigurations = (A00000000000000000000014, A00000000000000000000015); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };
  A00000000000000000000012 = {isa = XCBuildConfiguration; buildSettings = {CLANG_ENABLE_MODULES = YES; CLANG_ENABLE_OBJC_ARC = YES; SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SWIFT_VERSION = 6.0; SWIFT_OPTIMIZATION_LEVEL = "-Onone"; SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)"; DEBUG_INFORMATION_FORMAT = dwarf; ENABLE_TESTABILITY = YES; ONLY_ACTIVE_ARCH = YES; }; name = Debug; };
  A00000000000000000000013 = {isa = XCBuildConfiguration; buildSettings = {CLANG_ENABLE_MODULES = YES; CLANG_ENABLE_OBJC_ARC = YES; SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SWIFT_VERSION = 6.0; SWIFT_OPTIMIZATION_LEVEL = "-O"; SWIFT_COMPILATION_MODE = wholemodule; DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym"; DEAD_CODE_STRIPPING = YES; }; name = Release; };
  A00000000000000000000014 = {isa = XCBuildConfiguration; buildSettings = {ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon; CODE_SIGN_STYLE = Automatic; DEVELOPMENT_TEAM = S2UPJPPKKG; CURRENT_PROJECT_VERSION = 5; GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = App/Info.plist; LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks"; MARKETING_VERSION = 1.0; PRODUCT_BUNDLE_IDENTIFIER = com.xavier.sudokulisa; PRODUCT_NAME = "$(TARGET_NAME)"; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; SUPPORTS_MACCATALYST = NO; TARGETED_DEVICE_FAMILY = 1; }; name = Debug; };
  A00000000000000000000015 = {isa = XCBuildConfiguration; buildSettings = {ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon; CODE_SIGN_STYLE = Automatic; DEVELOPMENT_TEAM = S2UPJPPKKG; CURRENT_PROJECT_VERSION = 5; GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = App/Info.plist; LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks"; MARKETING_VERSION = 1.0; PRODUCT_BUNDLE_IDENTIFIER = com.xavier.sudokulisa; PRODUCT_NAME = "$(TARGET_NAME)"; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; SUPPORTS_MACCATALYST = NO; TARGETED_DEVICE_FAMILY = 1; }; name = Release; };
  A00000000000000000000020 = {isa = XCLocalSwiftPackageReference; relativePath = .; };
  A00000000000000000000021 = {isa = XCSwiftPackageProductDependency; package = A00000000000000000000020; productName = SudokuCore; };
  A00000000000000000000022 = {isa = PBXBuildFile; productRef = A00000000000000000000021; };
  A00000000000000000000023 = {isa = PBXFileSystemSynchronizedBuildFileExceptionSet; membershipExceptions = (Info.plist); target = A00000000000000000000002; };
 };
 rootObject = A00000000000000000000001;
}
'''

EXTRA_OBJECTS = '''
  B00000000000000000000001 = {isa = PBXNativeTarget; buildConfigurationList = B00000000000000000000010; buildPhases = (B00000000000000000000007, B00000000000000000000008, B00000000000000000000009); buildRules = (); dependencies = (B00000000000000000000020); fileSystemSynchronizedGroups = (B00000000000000000000005); name = LisaUITests; productName = LisaUITests; productReference = B00000000000000000000006; productType = "com.apple.product-type.bundle.ui-testing"; };
  B00000000000000000000005 = {isa = PBXFileSystemSynchronizedRootGroup; path = UITests; sourceTree = "<group>"; };
  B00000000000000000000006 = {isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = LisaUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR; };
  B00000000000000000000007 = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
  B00000000000000000000008 = {isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
  B00000000000000000000009 = {isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
  B00000000000000000000010 = {isa = XCConfigurationList; buildConfigurations = (B00000000000000000000011, B00000000000000000000012); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };
  B00000000000000000000011 = {isa = XCBuildConfiguration; buildSettings = {CODE_SIGN_STYLE = Automatic; DEVELOPMENT_TEAM = S2UPJPPKKG; GENERATE_INFOPLIST_FILE = YES; PRODUCT_BUNDLE_IDENTIFIER = com.xavier.sudokulisa.uitests; PRODUCT_NAME = "$(TARGET_NAME)"; TARGETED_DEVICE_FAMILY = 1; TEST_TARGET_NAME = SudokuLisa; }; name = Debug; };
  B00000000000000000000012 = {isa = XCBuildConfiguration; buildSettings = {CODE_SIGN_STYLE = Automatic; DEVELOPMENT_TEAM = S2UPJPPKKG; GENERATE_INFOPLIST_FILE = YES; PRODUCT_BUNDLE_IDENTIFIER = com.xavier.sudokulisa.uitests; PRODUCT_NAME = "$(TARGET_NAME)"; TARGETED_DEVICE_FAMILY = 1; TEST_TARGET_NAME = SudokuLisa; }; name = Release; };
  B00000000000000000000020 = {isa = PBXTargetDependency; target = A00000000000000000000002; targetProxy = B00000000000000000000021; };
  B00000000000000000000021 = {isa = PBXContainerItemProxy; containerPortal = A00000000000000000000001; proxyType = 1; remoteGlobalIDString = A00000000000000000000002; remoteInfo = SudokuLisa; };
  C00000000000000000000001 = {isa = PBXNativeTarget; buildConfigurationList = C00000000000000000000010; buildPhases = (C00000000000000000000007, C00000000000000000000008, C00000000000000000000009); buildRules = (); dependencies = (); fileSystemSynchronizedGroups = (C00000000000000000000005); name = LisaStickers; productName = LisaStickers; productReference = C00000000000000000000006; productType = "com.apple.product-type.app-extension.messages"; };
  C00000000000000000000005 = {isa = PBXFileSystemSynchronizedRootGroup; exceptions = (C00000000000000000000023); path = Stickers; sourceTree = "<group>"; };
  C00000000000000000000006 = {isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = LisaStickers.appex; sourceTree = BUILT_PRODUCTS_DIR; };
  C00000000000000000000007 = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
  C00000000000000000000008 = {isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
  C00000000000000000000009 = {isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
  C00000000000000000000010 = {isa = XCConfigurationList; buildConfigurations = (C00000000000000000000011, C00000000000000000000012); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };
  C00000000000000000000011 = {isa = XCBuildConfiguration; buildSettings = {APPLICATION_EXTENSION_API_ONLY = YES; ASSETCATALOG_COMPILER_APPICON_NAME = "iMessage App Icon"; CODE_SIGN_STYLE = Automatic; DEVELOPMENT_TEAM = S2UPJPPKKG; CURRENT_PROJECT_VERSION = 5; GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = Stickers/Info.plist; LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks"; MARKETING_VERSION = 1.0; PRODUCT_BUNDLE_IDENTIFIER = com.xavier.sudokulisa.LisaStickers; PRODUCT_NAME = "$(TARGET_NAME)"; SKIP_INSTALL = YES; TARGETED_DEVICE_FAMILY = 1; }; name = Debug; };
  C00000000000000000000012 = {isa = XCBuildConfiguration; buildSettings = {APPLICATION_EXTENSION_API_ONLY = YES; ASSETCATALOG_COMPILER_APPICON_NAME = "iMessage App Icon"; CODE_SIGN_STYLE = Automatic; DEVELOPMENT_TEAM = S2UPJPPKKG; CURRENT_PROJECT_VERSION = 5; GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = Stickers/Info.plist; LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks"; MARKETING_VERSION = 1.0; PRODUCT_BUNDLE_IDENTIFIER = com.xavier.sudokulisa.LisaStickers; PRODUCT_NAME = "$(TARGET_NAME)"; SKIP_INSTALL = YES; TARGETED_DEVICE_FAMILY = 1; }; name = Release; };
  C00000000000000000000020 = {isa = PBXTargetDependency; target = C00000000000000000000001; targetProxy = C00000000000000000000021; };
  C00000000000000000000021 = {isa = PBXContainerItemProxy; containerPortal = A00000000000000000000001; proxyType = 1; remoteGlobalIDString = C00000000000000000000001; remoteInfo = LisaStickers; };
  C00000000000000000000022 = {isa = PBXBuildFile; fileRef = C00000000000000000000006; settings = {ATTRIBUTES = (RemoveHeadersOnCopy); }; };
  C00000000000000000000023 = {isa = PBXFileSystemSynchronizedBuildFileExceptionSet; membershipExceptions = (Info.plist); target = C00000000000000000000001; };
  C00000000000000000000024 = {isa = PBXCopyFilesBuildPhase; buildActionMask = 2147483647; dstPath = ""; dstSubfolderSpec = 13; files = (C00000000000000000000022); name = "Embed App Extensions"; runOnlyForDeploymentPostprocessing = 0; };
'''

# Hosted unit tests exercise the actual app store, including @Published observers.
UNIT_OBJECTS = (
    EXTRA_OBJECTS[:EXTRA_OBJECTS.index("  C000")]
    .replace("B000", "D000")
    .replace("LisaUITests", "LisaStoreTests")
    .replace("path = UITests", "path = AppTests")
    .replace("bundle.ui-testing", "bundle.unit-test")
    .replace("com.xavier.sudokulisa.uitests", "com.xavier.sudokulisa.storetests")
    .replace("TEST_TARGET_NAME = SudokuLisa;",
             'BUNDLE_LOADER = "$(TEST_HOST)"; TEST_HOST = "$(BUILT_PRODUCTS_DIR)/SudokuLisa.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/SudokuLisa";')
)

def with_unit_tests(project):
    project = project.replace(" objects = {", " objects = {" + UNIT_OBJECTS)
    project = project.replace("B00000000000000000000001, C000", "B00000000000000000000001, D00000000000000000000001, C000")
    project = project.replace("B00000000000000000000005, C000", "B00000000000000000000005, D00000000000000000000005, C000")
    project = project.replace("B00000000000000000000006, C000", "B00000000000000000000006, D00000000000000000000006, C000")
    return project

def with_extra_targets(project):
    project = project.replace("ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;", "ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon; CODE_SIGN_ENTITLEMENTS = App/SudokuLisa.entitlements;")
    project = project.replace("membershipExceptions = (Info.plist); target = A", "membershipExceptions = (Info.plist, SudokuLisa.entitlements); target = A")
    project = project.replace("targets = (A00000000000000000000002);", "targets = (A00000000000000000000002, B00000000000000000000001, C00000000000000000000001);")
    project = project.replace("children = (A00000000000000000000005, A00000000000000000000004);", "children = (A00000000000000000000005, B00000000000000000000005, C00000000000000000000005, A00000000000000000000004);")
    project = project.replace("children = (A00000000000000000000006);", "children = (A00000000000000000000006, B00000000000000000000006, C00000000000000000000006);")
    project = project.replace("A00000000000000000000009); buildRules = (); dependencies = ();", "A00000000000000000000009, C00000000000000000000024); buildRules = (); dependencies = (C00000000000000000000020);")
    return project.replace(" objects = {", " objects = {" + EXTRA_OBJECTS)

SCHEME = '''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
    <BuildActionEntries>
      <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
        <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="A00000000000000000000002" BuildableName="SudokuLisa.app" BlueprintName="SudokuLisa" ReferencedContainer="container:SudokuLisa.xcodeproj"/>
      </BuildActionEntry>
      <BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES">
        <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="B00000000000000000000001" BuildableName="LisaUITests.xctest" BlueprintName="LisaUITests" ReferencedContainer="container:SudokuLisa.xcodeproj"/>
      </BuildActionEntry>
    </BuildActionEntries>
  </BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES">
    <Testables><TestableReference skipped="NO" parallelizable="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="B00000000000000000000001" BuildableName="LisaUITests.xctest" BlueprintName="LisaUITests" ReferencedContainer="container:SudokuLisa.xcodeproj"/></TestableReference></Testables>
  </TestAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="A00000000000000000000002" BuildableName="SudokuLisa.app" BlueprintName="SudokuLisa" ReferencedContainer="container:SudokuLisa.xcodeproj"/></BuildableProductRunnable></LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugServiceExtension="internal"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="A00000000000000000000002" BuildableName="SudokuLisa.app" BlueprintName="SudokuLisa" ReferencedContainer="container:SudokuLisa.xcodeproj"/></BuildableProductRunnable></ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''

if __name__ == "__main__":
    project_dir = ROOT / "SudokuLisa.xcodeproj"
    project_dir.mkdir(exist_ok=True)
    (project_dir / "project.pbxproj").write_text(with_unit_tests(with_extra_targets(PROJECT)))
    scheme_dir = project_dir / "xcshareddata" / "xcschemes"
    scheme_dir.mkdir(parents=True, exist_ok=True)
    unit_reference = '<TestableReference skipped="NO" parallelizable="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="D00000000000000000000001" BuildableName="LisaStoreTests.xctest" BlueprintName="LisaStoreTests" ReferencedContainer="container:SudokuLisa.xcodeproj"/></TestableReference>'
    (scheme_dir / "SudokuLisa.xcscheme").write_text(SCHEME.replace("</Testables>", unit_reference + "</Testables>"))
    print("Generated SudokuLisa.xcodeproj with LisaUITests, LisaStoreTests and LisaStickers targets")
