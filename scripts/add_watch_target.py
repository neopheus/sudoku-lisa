#!/usr/bin/env python3
"""Add Lisa's watch target without regenerating the existing Xcode project."""
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
PREFIX = 'E000000000000000000000'
def ident(number): return PREFIX + f'{number:02X}'

def add_watch_target(path=ROOT / 'SudokuLisa.xcodeproj/project.pbxproj'):
    path = Path(path)
    source = path.read_text()
    parsed = json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(path)]))
    objects = parsed['objects']
    has_watch = any(obj.get('name') == 'LisaWatch' and obj.get('isa') == 'PBXNativeTarget' for obj in objects.values())
    if not has_watch and any(ident(n) in objects for n in range(1, 25)):
        raise ValueError('Watch object IDs collide with existing project objects')
    project_id = parsed['rootObject']
    project = objects[project_id]
    phone_id = next(key for key, obj in objects.items() if obj.get('isa') == 'PBXNativeTarget' and obj.get('name') == 'SudokuLisa')
    package_id = next(key for key, obj in objects.items() if obj.get('isa') == 'XCLocalSwiftPackageReference' and obj.get('relativePath') == '.')
    phone = objects[phone_id]
    phone_configs = objects[phone['buildConfigurationList']]['buildConfigurations']
    inherited = objects[phone_configs[0]]['buildSettings']
    def append(object_id, field, value):
        nonlocal source
        match = re.search(r'^\s*' + object_id + r'\b[^=\n]*=\s*\{', source, re.M)
        if not match: raise ValueError(f'Missing object {object_id}')
        start = match.end() - 1
        depth, quote, escape, end = 0, False, False, start
        for end in range(start, len(source)):
            char = source[end]
            if quote:
                if escape: escape = False
                elif char == '\\': escape = True
                elif char == '"': quote = False
            elif char == '"': quote = True
            elif char == '{': depth += 1
            elif char == '}':
                depth -= 1
                if depth == 0: break
        block = source[start:end + 1]
        array = re.search(r'\b' + re.escape(field) + r'\s*=\s*\((.*?)\);', block, re.S)
        if not array: raise ValueError(f'Missing {object_id}.{field}')
        contents = array.group(1).rstrip()
        if contents and not contents.endswith(','): contents += ','
        replacement = contents + '\n\t\t\t\t' + value + ',\n\t\t\t'
        block = block[:array.start(1)] + replacement + block[array.end(1):]
        source = source[:start] + block + source[end + 1:]
    # Also reconcile the phone dependency and push entitlement build variable.
    phone_product = 'A00000000000000000000041'
    phone_build = 'A00000000000000000000042'
    dependency = next((key for key in phone.get('packageProductDependencies', []) if objects[key].get('productName') == 'LisaInvitations'), None)
    if dependency is None:
        if phone_product in objects or phone_build in objects:
            raise ValueError('Invitation product IDs collide with existing objects')
        append(phone_id, 'packageProductDependencies', phone_product)
        frameworks = next(key for key in phone['buildPhases'] if objects[key]['isa'] == 'PBXFrameworksBuildPhase')
        append(frameworks, 'files', phone_build)
        extras_phone = f'\n\t\t{phone_product} = {{isa = XCSwiftPackageProductDependency; package = {package_id}; productName = LisaInvitations;}};\n\t\t{phone_build} = {{isa = PBXBuildFile; productRef = {phone_product};}};\n'
        source = source.replace('objects = {', 'objects = {' + extras_phone, 1)
    for config_id in phone_configs:
        config = objects[config_id]
        value = 'development' if config['name'] == 'Debug' else 'production'
        pattern = r'(\b' + config_id + r'\b[^=\n]*=\s*\{.*?buildSettings\s*=\s*\{)(.*?)(\n?\s*\};)'
        def setting(match):
            block = match.group(2)
            if re.search(r'\bAPS_ENVIRONMENT\s*=', block):
                block = re.sub(r'\bAPS_ENVIRONMENT\s*=\s*[^;]*;', f'APS_ENVIRONMENT = {value};', block)
            else:
                block = f'\n\t\t\t\tAPS_ENVIRONMENT = {value};' + block
            return match.group(1) + block + match.group(3)
        source, count = re.subn(pattern, setting, source, count=1, flags=re.S)
        if count != 1: raise ValueError(f'Missing phone configuration {config_id}')
    def share_poulpi_sources():
        nonlocal source
        # Compile the exact iPhone model on Watch; never keep a second sculpt.
        if ident(32) in objects:
            return
        if any(ident(n) in objects for n in range(32, 45)):
            raise ValueError('Shared Poulpi object IDs collide with existing objects')
        shared = [
            (32, 'App/Design/LisaMascotMood.swift', 'sourcecode.swift', 7),
            (34, 'App/Design/PoulpiRig.swift', 'sourcecode.swift', 7),
            (36, 'App/Design/OctopusModel.swift', 'sourcecode.swift', 7),
            (38, 'App/Resources/Mascot/poulpi-rig.json', 'text.json', 9),
            (40, 'App/Resources/Mascot/poulpi-eye-reference.png', 'image.png', 9),
        ]
        additions = ''
        for n, resource, file_type, phase in shared:
            additions += f'\n\t\t{ident(n)} = {{isa = PBXFileReference; lastKnownFileType = {file_type}; path = "{resource}"; sourceTree = SOURCE_ROOT;}};\n'
            additions += f'\t\t{ident(n+1)} = {{isa = PBXBuildFile; fileRef = {ident(n)};}};\n'
            append(ident(phase), 'files', ident(n+1))
        additions += f'\t\t{ident(42)} = {{isa = XCSwiftPackageProductDependency; package = {package_id}; productName = SudokuCore;}};\n'
        additions += f'\t\t{ident(43)} = {{isa = PBXBuildFile; productRef = {ident(42)};}};\n'
        children = ', '.join(ident(n) for n, _, _, _ in shared)
        additions += f'\t\t{ident(44)} = {{isa = PBXGroup; children = ({children}); name = "Poulpi shared with Watch"; sourceTree = "<group>";}};\n'
        append(ident(1), 'packageProductDependencies', ident(42))
        append(ident(8), 'files', ident(43))
        append(project['mainGroup'], 'children', ident(44))
        source = source.replace('objects = {', 'objects = {' + additions, 1)

    if has_watch:
        share_poulpi_sources()
        if source != path.read_text():
            candidate = path.with_suffix('.watch-tmp')
            candidate.write_text(source)
            try:
                subprocess.run(['plutil', '-lint', str(candidate)], check=True, stdout=subprocess.DEVNULL)
                candidate.replace(path)
            finally:
                candidate.unlink(missing_ok=True)
        return False
    append(project_id, 'targets', ident(1))
    append(project['mainGroup'], 'children', ident(5))
    append(project['productRefGroup'], 'children', ident(6))
    append(phone_id, 'buildPhases', ident(18))
    append(phone_id, 'dependencies', ident(19))
    def obj(n, body): return f'\n\t\t{ident(n)} = {{{body}}};\n'
    extras = ''
    extras += obj(1, f'isa = PBXNativeTarget; buildConfigurationList = {ident(10)}; buildPhases = ({ident(7)}, {ident(8)}, {ident(9)}); buildRules = (); dependencies = (); fileSystemSynchronizedGroups = ({ident(5)}); name = LisaWatch; packageProductDependencies = ({ident(16)}); productName = LisaWatch; productReference = {ident(6)}; productType = "com.apple.product-type.application";')
    extras += obj(5, f'isa = PBXFileSystemSynchronizedRootGroup; exceptions = ({ident(15)}); explicitFileTypes = {{}}; explicitFolders = (); path = Watch; sourceTree = "<group>";')
    extras += obj(6, 'isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = LisaWatch.app; sourceTree = BUILT_PRODUCTS_DIR;')
    for n, isa in [(7,'PBXSourcesBuildPhase'),(8,'PBXFrameworksBuildPhase'),(9,'PBXResourcesBuildPhase')]:
        extras += obj(n, f'isa = {isa}; buildActionMask = 2147483647; files = ({ident(17) if n == 8 else ""}); runOnlyForDeploymentPostprocessing = 0;')
    extras += obj(10, f'isa = XCConfigurationList; buildConfigurations = ({ident(11)}, {ident(12)}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
    for n, name in [(11,'Debug'),(12,'Release')]:
        settings = {'ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','APS_ENVIRONMENT':'development' if name == 'Debug' else 'production','CODE_SIGN_STYLE':'Automatic','CODE_SIGN_ENTITLEMENTS':'Watch/LisaWatch.entitlements','DEVELOPMENT_TEAM':inherited.get('DEVELOPMENT_TEAM',''),'CURRENT_PROJECT_VERSION':inherited.get('CURRENT_PROJECT_VERSION','1'),'GENERATE_INFOPLIST_FILE':'NO','INFOPLIST_FILE':'Watch/Info.plist','MARKETING_VERSION':inherited.get('MARKETING_VERSION','1.0'),'PRODUCT_BUNDLE_IDENTIFIER':'com.xavier.sudokulisa.watchkitapp','PRODUCT_NAME':'$(TARGET_NAME)','SDKROOT':'watchos','SUPPORTED_PLATFORMS':'watchos watchsimulator','TARGETED_DEVICE_FAMILY':'4','WATCHOS_DEPLOYMENT_TARGET':'10.0','SWIFT_VERSION':'6.0','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks','SKIP_INSTALL':'YES','SWIFT_OPTIMIZATION_LEVEL':'-Onone' if name == 'Debug' else '-O'}
        settings_text = ' '.join(f'{key} = {json.dumps(str(value))};' for key,value in settings.items())
        extras += obj(n, f'isa = XCBuildConfiguration; buildSettings = {{{settings_text}}}; name = {name};')
    extras += obj(15, f'isa = PBXFileSystemSynchronizedBuildFileExceptionSet; membershipExceptions = (Info.plist, LisaWatch.entitlements, README.md, Validation/MiniSudokuChecks.swift); target = {ident(1)};')
    extras += obj(16, f'isa = XCSwiftPackageProductDependency; package = {package_id}; productName = LisaInvitations;')
    extras += obj(17, f'isa = PBXBuildFile; productRef = {ident(16)};')
    extras += obj(18, f'isa = PBXCopyFilesBuildPhase; buildActionMask = 2147483647; dstPath = "$(CONTENTS_FOLDER_PATH)/Watch"; dstSubfolderSpec = 16; files = ({ident(21)}); name = "Embed Watch Content"; runOnlyForDeploymentPostprocessing = 0;')
    extras += obj(19, f'isa = PBXTargetDependency; target = {ident(1)}; targetProxy = {ident(20)};')
    extras += obj(20, f'isa = PBXContainerItemProxy; containerPortal = {project_id}; proxyType = 1; remoteGlobalIDString = {ident(1)}; remoteInfo = LisaWatch;')
    extras += obj(21, f'isa = PBXBuildFile; fileRef = {ident(6)}; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy);}};')
    source = source.replace('objects = {', 'objects = {' + extras, 1)
    share_poulpi_sources()
    candidate = path.with_suffix('.watch-tmp')
    candidate.write_text(source)
    try:
        subprocess.run(['plutil','-lint',str(candidate)],check=True,stdout=subprocess.DEVNULL)
        candidate.replace(path)
    finally:
        candidate.unlink(missing_ok=True)
    scheme = path.parent / 'xcshareddata/xcschemes/LisaWatch.xcscheme'
    scheme.parent.mkdir(parents=True, exist_ok=True)
    ref = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ident(1)}" BuildableName="LisaWatch.app" BlueprintName="LisaWatch" ReferencedContainer="container:SudokuLisa.xcodeproj"/>'
    scheme.write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref}</BuildActionEntry></BuildActionEntries></BuildAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
    return True

if __name__ == '__main__':
    print('Watch target added.' if add_watch_target(Path(sys.argv[1]) if len(sys.argv)>1 else ROOT/'SudokuLisa.xcodeproj/project.pbxproj') else 'Watch target already exists.')
