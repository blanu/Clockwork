//
//  ClockworkSpacetime.swift
//
//
//  Created by Dr. Brandon Wiley on 1/8/23.
//

import ArgumentParser
import Foundation

import Gardener

public class ClockworkSpacetime
{
    public init()
    {
    }

    public func generate(sources: String, output: String) throws
    {
        guard File.isDirectory(sources) else
        {
            throw ClockworkSpacetimeError.sourcesDirectoryDoesNotExist
        }

        let outputURL = URL(fileURLWithPath: output)
        if !File.exists(output)
        {
            guard File.makeDirectory(url: outputURL) else
            {
                throw ClockworkSpacetimeError.noOutputDirectory
            }
        }

        let sourceURL = URL(fileURLWithPath: sources)
        let files = File.findFiles(sourceURL, pattern: "*.swift")
        let _ = files.map { self.generate($0, outputURL) }
    }

    public func generate(_ input: URL, _ outputURL: URL)
    {
        do
        {
            let source = try String(contentsOf: input)
            let className = try self.findClassName(source)

            let functions = try self.findFunctions(source)

            guard functions.count > 0 else
            {
                return
            }

            try self.generateInteractions(outputURL, className, functions)
            try self.generateUniverseExtension(outputURL, className, functions)
            try self.generateModule(outputURL, className, functions)
        }
        catch
        {
            print(error)
        }
    }

    func findClassName(_ source: String) throws -> String
    {
        let regex = try Regex("class [A-Za-z0-9]+")
        let ranges = source.ranges(of: regex)
        guard ranges.count == 1 else
        {
            if ranges.count == 0
            {
                throw ClockworkSpacetimeError.noMatches
            }
            else
            {
                throw ClockworkSpacetimeError.tooManyMatches
            }
        }

        return String(source[ranges[0]].split(separator: " ")[1])
    }

    func findFunctions(_ source: String) throws -> [Function]
    {
        let regex = try Regex("public func [A-Za-z0-9]+\\([^\\)]*\\)( throws)?( -> [A-Za-z0-9]+)?")
        let results = source.ranges(of: regex).map
        {
            range in

            let substrings = source[range].split(separator: " ")[2...]
            let strings = substrings.map { String($0) }
            return strings.joined(separator: " ")
        }

        return results.compactMap
        {
            function in

            do
            {
                let name = try self.findFunctionName(function)
                let parameters = try self.findParameters(function)
                let returnType = try self.findFunctionReturnType(function)
                let throwing = try self.findFunctionThrowing(function)
                return Function(name: name, parameters: parameters, returnType: returnType, throwing: throwing)
            }
            catch
            {
                return nil
            }
        }
    }

    func findFunctionName(_ function: String) throws -> String
    {
        return String(function.split(separator: "(")[0])
    }

    func findParameters(_ function: String) throws -> [FunctionParameter]
    {
        guard function.firstIndex(of: "@") == nil else
        {
            throw ClockworkSpacetimeError.badFunctionFormat
        }

        guard function.firstIndex(of: "_") == nil else
        {
            throw ClockworkSpacetimeError.badFunctionFormat
        }

        guard let parameterStart = function.firstIndex(of: "(") else
        {
            throw ClockworkSpacetimeError.badFunctionFormat
        }

        guard let parameterEnd = function.firstIndex(of: ")") else
        {
            throw ClockworkSpacetimeError.badFunctionFormat
        }

        if function.index(after: parameterStart) == parameterEnd
        {
            return []
        }

        let suffix = String(function.split(separator: "(")[1])
        let prefix = String(suffix.split(separator: ")")[0])
        let parts = prefix.split(separator: ", ").map { String($0) }
        return try parts.map
        {
            part in

            let subparts = part.split(separator: ": ")
            guard subparts.count == 2 else
            {
                throw ClockworkError.badFunctionFormat
            }

            let name = String(subparts[0])
            let type = String(subparts[1])
            return FunctionParameter(name: name, type: type)
        }
    }

    func findFunctionReturnType(_ function: String) throws -> String?
    {
        guard function.firstIndex(of: "-") != nil else
        {
            return nil
        }

        return String(function.split(separator: "-> ")[1])
    }

    func findFunctionThrowing(_ function: String) throws -> Bool
    {
        return function.split(separator: " throws ").count == 2
    }

    func generateRequestEnumsText(_ functions: [Function]) -> String
    {
        let enums = functions.map { self.generateRequestEnumCase($0) }
        return enums.joined(separator: "\n")
    }

    func generateRequestEnumCase(_ function: Function) -> String
    {
        if function.parameters.isEmpty
        {
            return "    case \(function.name)"
        }
        else
        {
            return "    case \(function.name)(\(function.name.capitalized))"
        }
    }

    func generateResponseEnumsText(_ functions: [Function]) throws -> String
    {
        let enums = try functions.map { try self.generateResponseEnumCase($0) }
        return enums.joined(separator: "\n")
    }

    func generateResponseEnumCase(_ function: Function) throws -> String
    {
        if let returnType = function.returnType
        {
            return "    case \(function.name)(\(returnType))"
        }
        else
        {
            return "    case \(function.name)"
        }
    }

    func generateParameter(_ parameter: FunctionParameter) -> String
    {
        return "\(parameter.name): \(parameter.type)"
    }

    func generateInit(_ parameter: FunctionParameter) -> String
    {
        return "        self.\(parameter.name) = \(parameter.name)"
    }
}

public enum ClockworkSpacetimeError: Error
{
    case sourcesDirectoryDoesNotExist
    case noMatches
    case tooManyMatches
    case badFunctionFormat
    case noOutputDirectory
    case templateNotFound
}
