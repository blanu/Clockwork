//
//  Clockwork.swift
//  
//
//  Created by Dr. Brandon Wiley on 1/5/23.
//

import ArgumentParser
import Foundation

import Gardener

public class Clockwork
{
    public init()
    {
    }

    public func generate(sources: String, output: String) throws
    {
        guard File.isDirectory(sources) else
        {
            throw ClockworkError.sourcesDirectoryDoesNotExist
        }

        let outputURL = URL(fileURLWithPath: output)
        if !File.exists(output)
        {
            guard File.makeDirectory(url: outputURL) else
            {
                throw ClockworkError.noOutputDirectory
            }
        }

        let sourceURL = URL(fileURLWithPath: sources)
        let files = File.findFiles(sourceURL, pattern: "**/*.swift")
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

            try self.generateMessages(outputURL, className, functions)
            try self.generateClient(outputURL, className, functions)
            try self.generateServer(outputURL, className, functions)
        }
        catch
        {
            print(error)
        }
    }

    public func generateMessages(_ input: URL, _ output: URL)
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

            let outputFile = output.appending(component: "\(className)Messages.swift")
            try self.generateMessages(outputFile, className, functions)
        }
        catch
        {
            print(error)
        }
    }

    public func generateClient(_ input: URL, _ output: URL)
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

            let outputFile = output.appending(component: "\(className)Client.swift")
            try self.generateClient(outputFile, className, functions)
        }
        catch
        {
            print(error)
        }
    }

    public func generateServer(_ input: URL, _ output: URL)
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

            let outputFile = output.appending(component: "\(className)Server.swift")
            try self.generateServer(outputFile, className, functions)
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
                throw ClockworkError.noMatches
            }
            else
            {
                throw ClockworkError.tooManyMatches
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
            throw ClockworkError.badFunctionFormat
        }

        guard function.firstIndex(of: "_") == nil else
        {
            throw ClockworkError.badFunctionFormat
        }

        guard let parameterStart = function.firstIndex(of: "(") else
        {
            throw ClockworkError.badFunctionFormat
        }

        guard let parameterEnd = function.firstIndex(of: ")") else
        {
            throw ClockworkError.badFunctionFormat
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

    func generateMessages(_ outputURL: URL, _ className: String, _ functions: [Function]) throws
    {
        print("Generating \(className)Messages...")

        let outputFile = outputURL.appending(component: "\(className)Messages.swift")
        let result = try self.generateRequestText(className, functions)
        try result.write(to: outputFile, atomically: true, encoding: .utf8)
    }

    func generateClient(_ outputURL: URL, _ className: String, _ functions: [Function]) throws
    {
        print("Generating \(className)Client...")

        let outputFile = outputURL.appending(component: "\(className)Client.swift")
        let result = try self.generateClientText(className, functions)
        try result.write(to: outputFile, atomically: true, encoding: .utf8)
    }

    func generateServer(_ outputURL: URL, _ className: String, _ functions: [Function]) throws
    {
        print("Generating \(className)Server...")

        let outputFile = outputURL.appending(component: "\(className)Server.swift")
        let result = try self.generateServerText(className, functions)
        try result.write(to: outputFile, atomically: true, encoding: .utf8)
    }

    func generateRequestText(_ className: String, _ functions: [Function]) throws -> String
    {
        let date = Date() // now
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        let dateString = formatter.string(from: date)

        let requestEnums = self.generateRequestEnumsText(functions)
        let requestStructs = try self.generateRequestStructs(functions)

        let responseEnums = try self.generateResponseEnumsText(functions)

        return """
        //
        //  \(className)Messages.swift
        //
        //
        //  Created by Clockwork on \(dateString).
        //

        public enum \(className)Request: Codable
        {
        \(requestEnums)
        }

        \(requestStructs)

        public enum \(className)Response: Codable
        {
        \(responseEnums)
        }
        """
    }

    func generateClientText(_ className: String, _ functions: [Function]) throws -> String
    {
        let date = Date() // now
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        let dateString = formatter.string(from: date)

        let functions = try self.generateFunctions(className, functions)

        return """
        //
        //  \(className)Client.swift
        //
        //
        //  Created by Clockwork on \(dateString).
        //

        import Foundation

        import TransmissionTypes

        public class \(className)Client
        {
            let connection: TransmissionTypes.Connection

            public init(connection: TransmissionTypes.Connection)
            {
                self.connection = connection
            }

        \(functions)
        }

        public enum \(className)ClientError: Error
        {
            case connectionRefused(String, Int)
            case writeFailed
            case readFailed
            case badReturnType
        }
        """
    }

    func generateServerText(_ className: String, _ functions: [Function]) throws -> String
    {
        let date = Date() // now
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        let dateString = formatter.string(from: date)

        let cases = self.generateServerCases(className, functions)

        return """
        //
        //  \(className)Server.swift
        //
        //
        //  Created by Clockwork on \(dateString).
        //

        import Foundation

        import TransmissionTypes

        public class \(className)Server
        {
            let listener: TransmissionTypes.Listener
            let handler: \(className)

            var running: Bool = true

            public init(listener: TransmissionTypes.Listener, handler: \(className))
            {
                self.listener = listener
                self.handler = handler

                Task
                {
                    self.acceptLoop()
                }
            }

            public func shutdown()
            {
                self.running = false
            }

            func acceptLoop()
            {
                while self.running
                {
                    do
                    {
                        let connection = try self.listener.accept()

                        Task
                        {
                            self.handleConnection(connection)
                        }
                    }
                    catch
                    {
                        print(error)
                        self.running = false
                        return
                    }
                }
            }

            func handleConnection(_ connection: TransmissionTypes.Connection)
            {
                while self.running
                {
                    do
                    {
                        guard let requestData = connection.readWithLengthPrefix(prefixSizeInBits: 64) else
                        {
                            throw \(className)ServerError.readFailed
                        }

                        let decoder = JSONDecoder()
                        let request = try decoder.decode(\(className)Request.self, from: requestData)
                        switch request
                        {
        \(cases)
                        }
                    }
                    catch
                    {
                        print(error)
                        return
                    }
                }
            }
        }

        public enum \(className)ServerError: Error
        {
            case connectionRefused(String, Int)
            case writeFailed
            case readFailed
            case badReturnType
        }
        """
    }

    func generateServerCases(_ className: String, _ functions: [Function]) -> String
    {
        let cases = functions.map { self.generateServerCase(className, $0) }
        return cases.joined(separator: "\n")
    }

    func generateServerCase(_ className: String, _ function: Function) -> String
    {
        if function.parameters.isEmpty
        {
            if function.returnType == nil
            {
                return """
                                    case .\(function.name):
                                        self.handler.\(function.name)()
                                        let response = \(className)Response.\(function.name)
                                        let encoder = JSONEncoder()
                                        let responseData = try encoder.encode(response)
                                        guard connection.writeWithLengthPrefix(data: responseData, prefixSizeInBits: 64) else
                                        {
                                            throw \(className)ServerError.writeFailed
                                        }
                """
            }
            else
            {
                return """
                                    case .\(function.name):
                                        let result = self.handler.\(function.name)()
                                        let response = \(className)Response.\(function.name)(result)
                                        let encoder = JSONEncoder()
                                        let responseData = try encoder.encode(response)
                                        guard connection.writeWithLengthPrefix(data: responseData, prefixSizeInBits: 64) else
                                        {
                                            throw \(className)ServerError.writeFailed
                                        }
                """
            }
        }
        else
        {
            let arguments = function.parameters.map { self.generateServerArgument($0) }
            let argumentList = arguments.joined(separator: ", ")

            if function.returnType == nil
            {
                return """
                                    case .\(function.name)(let value):
                                        self.handler.\(function.name)(\(argumentList))
                                        let response = \(className)Response.\(function.name)
                                        let encoder = JSONEncoder()
                                        let responseData = try encoder.encode(response)
                                        guard connection.writeWithLengthPrefix(data: responseData, prefixSizeInBits: 64) else
                                        {
                                            throw \(className)ServerError.writeFailed
                                        }
                """
            }
            else
            {
                return """
                                    case .\(function.name)(let value):
                                        let result = self.handler.\(function.name)(\(argumentList))
                                        let response = \(className)Response.\(function.name)(result)
                                        let encoder = JSONEncoder()
                                        let responseData = try encoder.encode(response)
                                        guard connection.writeWithLengthPrefix(data: responseData, prefixSizeInBits: 64) else
                                        {
                                            throw \(className)ServerError.writeFailed
                                        }
                """
            }
        }
    }

    func generateServerArgument(_ parameter: FunctionParameter) -> String
    {
        return "\(parameter.name): value.\(parameter.name)"
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

    func generateRequestStructs(_ functions: [Function]) throws -> String
    {
        let structs = try functions.compactMap { try self.generateStruct($0) }
        return structs.joined(separator: "\n\n")
    }

    func generateStruct(_ function: Function) throws -> String?
    {
        if function.parameters.isEmpty
        {
            return nil
        }

        let fields = function.parameters.map { self.generateStructField($0) }
        let fieldList = fields.joined(separator: "\n")

        let parameters = function.parameters.map { self.generateParameter($0) }
        let parameterList = parameters.joined(separator: ", ")

        let inits = function.parameters.map { self.generateInit($0) }
        let initList = inits.joined(separator: "\n")

        return """
        public struct \(function.name.capitalized): Codable
        {
        \(fieldList)

            public init(\(parameterList))
            {
        \(initList)
            }
        }
        """
    }

    func generateStructField(_ parameter: FunctionParameter) -> String
    {
        return "    let \(parameter.name): \(parameter.type)"
    }

    func generateParameter(_ parameter: FunctionParameter) -> String
    {
        return "\(parameter.name): \(parameter.type)"
    }

    func generateInit(_ parameter: FunctionParameter) -> String
    {
        return "        self.\(parameter.name) = \(parameter.name)"
    }

    func generateFunctions(_ className: String, _ functions: [Function]) throws -> String
    {
        let results = try functions.compactMap { try self.generateFunction(className, $0, includeDefault: functions.count > 1) }
        return results.joined(separator: "\n\n")
    }

    func generateFunction(_ className: String, _ function: Function, includeDefault: Bool) throws -> String
    {
        let signature = self.generateFunctionSignature(function)
        let body = self.generateFunctionBody(className, function, includeDefault: includeDefault)

        return """
        \(signature)
        \(body)
        """
    }

    func generateFunctionSignature( _ function: Function) -> String
    {
        let parameters = function.parameters.map { self.generateParameter($0) }
        let parameterList = parameters.joined(separator: ", ")

        if let returnType = function.returnType
        {
            return "    public func \(function.name)(\(parameterList)) throws -> \(returnType)"
        }
        else
        {
            return "    public func \(function.name)(\(parameterList)) throws"
        }
    }

    func generateFunctionBody(_ className: String, _ function: Function, includeDefault: Bool) -> String
    {
        let structHandler: String
        if function.parameters.isEmpty
        {
            structHandler = ""
        }
        else
        {
            let arguments = function.parameters.map { self.generateArgument($0) }
            let argumentList = arguments.joined(separator: ", ")
            structHandler = "(\(function.name.capitalized)(\(argumentList)))"
        }

        let returnHandler: String
        if function.returnType == nil
        {
            returnHandler = """
                        case .\(function.name):
                            return
            """
        }
        else
        {
            returnHandler = """
                        case .\(function.name)(let value):
                            return value
            """
        }

        let defaultHandler: String
        if includeDefault
        {
            defaultHandler = """
                        default:
                            throw \(className)ClientError.badReturnType
            """
        }
        else
        {
            defaultHandler = ""
        }

        return """
            {
                let message = \(className)Request.\(function.name)\(structHandler)
                let encoder = JSONEncoder()
                let data = try encoder.encode(message)
                guard self.connection.writeWithLengthPrefix(data: data, prefixSizeInBits: 64) else
                {
                    throw \(className)ClientError.writeFailed
                }

                guard let responseData = self.connection.readWithLengthPrefix(prefixSizeInBits: 64) else
                {
                    throw \(className)ClientError.readFailed
                }

                let decoder = JSONDecoder()
                let response = try decoder.decode(\(className)Response.self, from: responseData)
                switch response
                {
        \(returnHandler)
        \(defaultHandler)
                }
            }
        """

    }

    func generateArgument(_ argument: FunctionParameter) -> String
    {
        return "\(argument.name): \(argument.name)"
    }

}

public struct Function
{
    let name: String
    let parameters: [FunctionParameter]
    let returnType: String?
    let throwing: Bool
}

public struct FunctionParameter
{
    let name: String
    let type: String
}

public enum ClockworkError: Error
{
    case sourcesDirectoryDoesNotExist
    case noMatches
    case tooManyMatches
    case badFunctionFormat
    case noOutputDirectory
    case templateNotFound
}
