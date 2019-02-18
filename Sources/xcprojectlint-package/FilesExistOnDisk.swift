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

private func recurseForMissingFiles(_ groups: [String], hierarchy: [String], project: Project, errors: Set<String>, errorReporter: ErrorReporter) -> Set<String> {
  let base = project.url.deletingLastPathComponent().deletingLastPathComponent()
  var errors = errors
  for child in groups {
    if let group = project.groups[child] {
      var next = hierarchy
      if let name = group.path {
        next.append(name)
      }
      errors = recurseForMissingFiles(group.children, hierarchy: next, project: project, errors: errors, errorReporter: errorReporter)
    } else if let file = project.fileReferences[child] {
      if let type = file.lastKnownFileType,
        type.hasPrefix("sourcecode.") {
        let uiPath = hierarchy.joined(separator: "/")
        var url = base
        if file.sourceTree == "<group>", uiPath.count > 0 {
          url = url.appendingPathComponent(uiPath)
        }
        url = url.appendingPathComponent(file.path)
        url = url.standardized
        
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: url.path) {
          let errStr = "\(project.url.path):0: \(errorReporter.reportKind.logEntry) \(uiPath) references files that are not on disk.\n"
          errors.insert(errStr)
        }
      }
    }
  }
  return errors
}

public func filesExistOnDisk(_ project: Project, errorReporter: ErrorReporter) -> Int32 {
  var result = EX_DATAERR
  if let proj = project.projectNodes.first {
    let mainGroup = proj.mainGroup
    let group = project.groups[mainGroup]
    
    let errors = Set<String>()
    if let children = group?.children {
      let results = recurseForMissingFiles(children, hierarchy: [], project: project, errors: errors, errorReporter: errorReporter).sorted()
      
      if results.count > 0 {
        result = errorReporter.reportKind.returnType
        for error in results {
          errorReporter.report(error)
        }
      } else {
        result = EX_OK
      }
    }
  }
  
  return result
}
