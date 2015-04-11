// The MIT License (MIT)
//
// Copyright (c) 2015 Suyeol Jeon (xoul.kr)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation


public typealias Number = NSNumber
public typealias Dict = [String: NSObject]


public func == (lhs: Any.Type, rhs: Any.Type) -> Bool {
    return ObjectIdentifier(lhs).hashValue == ObjectIdentifier(rhs).hashValue
}


internal class Property: Printable {
    var name: String!
    var type: Any.Type!
    var optional: Bool = false

    var typeDescription: String {
        var description = toString(self.type).stringByReplacingOccurrencesOfString(
            "Swift.",
            withString: "",
            options: .allZeros,
            range: nil
        )
        if self.optional {
            let start = advance(description.startIndex, "Optional<".length)
            let end = advance(description.endIndex, -1 * ">".length)
            let range = Range<String.Index>(start: start, end: end)
            description = description.substringWithRange(range) + "?"
        }
        return description
    }

    var modelClass: SuperModel.Type? {
        var className = self.typeDescription
        if self.optional {
            className = className.substringToIndex(advance(className.endIndex, -1))
        }
        return NSClassFromString(className) as? SuperModel.Type
    }

    var description: String {
        return "@property \(self.name): \(self.typeDescription)"
    }
}


public class SuperModel: NSObject {

    internal var properties: [Property] {
        if let cachedProperties = self.dynamicType.cachedProperties {
            return cachedProperties
        }

        let mirror = reflect(self)
        if mirror.count <= 1 {
            return [Property]()
        }

        var properties = [Property]()
        for i in 1..<mirror.count {
            let (name, propertyMirror) = mirror[i]

            let property = Property()
            property.name = name
            property.type = propertyMirror.valueType
            property.optional = propertyMirror.disposition == .Optional
            properties.append(property)
            println(property)
        }

        self.dynamicType.cachedProperties = properties
        return properties
    }

    internal class var cachedProperties: [Property]? {
        get {
            return objc_getAssociatedObject(self, "properties") as? [Property]
        }
        set {
            objc_setAssociatedObject(
                self,
                "properties",
                newValue,
                objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            )
        }
    }

    public class func fromList(list: [Dict]) -> [SuperModel] {
        return list.map { self.init($0) }
    }

    public convenience init(_ dictionary: Dict) {
        self.init()
        self.update(dictionary)
    }

    public func update(dictionary: Dict) {
        self.setValuesForKeysWithDictionary(dictionary)
    }

    public override func setValue(value: AnyObject?, forKey key: String) {
        if let property = self.properties.filter({ $0.name == key }).first where value != nil {
            let type = property.type

            // String
            if type == String.self || type == Optional<String>.self {
                if let value = value as? String {
                    super.setValue(value, forKey: key)
                } else if let value = value as? Number {
                    super.setValue(value.stringValue, forKey: key)
                }
            }

            // Number
            else if type == Number.self || type == Optional<Number>.self {
                if let value = value as? Number {
                    super.setValue(value, forKey: key)
                } else if let value = value as? String, number = self.dynamicType.numberFromString(value) {
                    super.setValue(number, forKey: key)
                }
            }

            // Relationship
            else if let modelClass = property.modelClass {
                if let dict = value as? Dict {
                    let model = modelClass.init(dict)
                    super.setValue(model, forKey: key)
                }
            }

            // What else?
            else {
                println("Else: \(key): \(type) = \(value)")
            }
        } else {
            super.setValue(value, forKey: key)
        }
    }

    public func toDictionary(nulls: Bool = false) -> Dict {
        var dictionary = Dict()
        for property in self.properties {
            if let value: AnyObject = self.valueForKey(property.name) {
                dictionary[property.name] = value as? NSObject
            } else if nulls {
                dictionary[property.name] = NSNull()
            }
        }
        return dictionary
    }

    private struct Shared {
        static let numberFormatter = NSNumberFormatter()
    }

    public class func numberFromString(string: String) -> Number? {
        let formatter = Shared.numberFormatter
        if formatter.numberStyle != .DecimalStyle {
            formatter.numberStyle = .DecimalStyle
        }
        return formatter.numberFromString(string)
    }

}
