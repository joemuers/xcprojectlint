/*
 * Copyright (c) 2018 American Express Travel Related Services Company, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License. You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software distributed under the License
 * is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
 * or implied. See the License for the specific language governing permissions and limitations under
 * the License.
 */

import Foundation

public func checkForInternalProjectSettings(_ project: Project, errorReporter: ErrorReporter) -> Int32 {
  var scriptResult = EX_OK
  
  for buildConfiguration in project.buildConfigurations {
    let settings = buildConfiguration.buildSettings
    guard settings.count > 0 else { continue } // this is a non-error
    
    scriptResult = errorReporter.reportKind.returnType  // if we get to this line, we've found at least one misplaced build setting
    
    guard project.titles[buildConfiguration.id] != nil else {
        errorReporter.report(error: ProjectSettingsError.problemLocatingMatchingConfiguration);
        return errorReporter.reportKind.returnType
    }

    var configFileName: String?
    if let base = buildConfiguration.baseConfigurationReference {
      configFileName = project.titles[base]
    } else {
      let target = project.legacyTargets.filter { $0.buildConfigurationList == buildConfiguration.id }
      configFileName = target.last?.name
    }

    // see if we can find the buildSettings node closest to this build configuration
    var currentLine = 0
    var foundKey = false
    for line in project.projectText.components(separatedBy: CharacterSet.newlines) {
      currentLine += 1
      if !foundKey {
        if line.contains(buildConfiguration.id) {
          foundKey = true
        }
      } else {
        if line.contains("buildSettings") {
          break
        }
      }
    }

    let errStr: String!
    let projectName = project.projectName.replacingOccurrences(of: ".xcodeproj", with: "")
    if buildConfig(buildConfiguration, isAtProjectLevelFor: project) {
        let configName = configFileName ?? "Project.\(projectName).\(buildConfiguration.name).xcconfig"
      errStr = "Project \"\(projectName)\" has build settings defined in the project file (at the project level). Please extract these settings to the config file \(configName) (or Project.\(projectName).shared.xcconfig if appropriate). \n"
    } else if let targetName = targetName(for: buildConfiguration, inProject: project) {
        let configName = configFileName ?? "Target.\(targetName).\(buildConfiguration.name).xcconfig"
        errStr = "Project \"\(projectName)\" has settings defined in the project file for target \"\(targetName)\" (\(buildConfiguration.name) configuration). Please extract these settings to the config file \(configName) (or Target.\(targetName).shared.xcconfig if appropriate). \n"
    } else {
        errStr = "Project \"\(projectName)\" has build settings defined in the project file. Please extract them to the corresponding .xcconfig file. \n"
    }
    
    errorReporter.report(errStr, lineNumber: currentLine)
  }
  
  return(scriptResult)
}

func buildConfig(_ buildConfig: BuildConfiguration, isAtProjectLevelFor project: Project) -> Bool {
    guard let projectNode = project.projectNodes.first else { return false }
    guard let buildConfigsList = project.buildConfigurationLists[projectNode.buildConfigurationList] else { return false }
    return buildConfigsList.buildConfigurations.contains(buildConfig.id)
}

func targetName(for buildConfig: BuildConfiguration, inProject project: Project) -> String? {
    for nativeTarget in project.nativeTargets {
        guard let projectConfigList = project.buildConfigurationLists[nativeTarget.buildConfigurationList] else { continue }
        if projectConfigList.buildConfigurations.contains(buildConfig.id) {
            return nativeTarget.name
        }
    }
    return nil
}

enum ProjectSettingsError: String, Error {
  // Some assumption we've made about the shape of a project file was wrong.
  case problemLocatingMatchingConfiguration = "We found buildSettings, but were not able to find the matching configuration."
}
