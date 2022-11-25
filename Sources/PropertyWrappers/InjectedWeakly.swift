//
// InjectedWeakly
// Macaroni
//
// Created by Alex Babaev on 29 May 2021.
// Copyright © 2021 Alex Babaev. All rights reserved.
// License: MIT License, https://github.com/bealex/Macaroni/blob/main/LICENSE
//

/// This wrapper can be used only with classes. You must capture injected object weakly (with [weak object]) in registration closure.
@propertyWrapper
public struct InjectedWeakly<Value> {
    public var wrappedValue: Value? {
        get { Macaroni.logger.die("Injecting only works for class enclosing types") }
        // We need setter here so that KeyPaths in subscript were writable.
        set { Macaroni.logger.die("Injecting only works for class enclosing types") }
    }

    // We need to strongly handle policy to be able to resolve lazily.
    private var findPolicyCapture: Injected<Value>.ContainerFindPolicyCapture = .onFirstUsage
    private var alternative: RegistrationAlternative?

    public init(
        _ initialization: Injected<Value>.InitializationKind = .fromContainer(),
        alternative: RegistrationAlternative? = nil,
        file: StaticString = #fileID, function: String = #function, line: UInt = #line
    ) {
        self.alternative = alternative
        switch initialization {
            case .immediate(let container):
                guard let container = container ?? Container.lookupPolicy.container(for: Self.self, file: file, function: function, line: line) else {
                    Macaroni.logger.die("Can't find container for InjectedWeakly immediateResolve", file: file, function: function, line: line)
                }

                do {
                    let storage: Value = try container.resolve()
                    self.storage = storage as AnyObject
                    Macaroni.logger.debug("Injecting (eager from container): \(String(describing: Value.self))\(alternative.map { "/\($0.name)" } ?? "")", file: file, function: function, line: line)
                } catch {
                    if container.isResolvable(Value.self) {
                        Macaroni.logger.die("Parametrized resolvers are not supported for greedy injection (\"\(String(describing: Value.self))\").", file: file, function: function, line: line)
                    } else {
                        Macaroni.logger.die("Dependency \"\(String(describing: Value.self))\" does not have a resolver", file: file, function: function, line: line)
                    }
                }
            case .fromContainer(let container):
                findPolicyCapture = .onInitialization(container.map(SingletonContainer.init) ?? Container.lookupPolicy)
            case .lazily:
                findPolicyCapture = .onFirstUsage
        }
    }

    private weak var storage: AnyObject?
    private var isResolved: Bool = false

    public static subscript<EnclosingType>(
        _enclosingInstance instance: EnclosingType,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingType, Value?>,
        storage storageKeyPath: ReferenceWritableKeyPath<EnclosingType, Self>
    ) -> Value? {
        get {
            let enclosingValue = instance[keyPath: storageKeyPath]
            if enclosingValue.isResolved, let value = enclosingValue.storage as? Value {
                return value
            } else {
                let alternative = instance[keyPath: storageKeyPath].alternative
                guard let findPolicy = instance[keyPath: storageKeyPath].findPolicyCapture.policy else {
                    Macaroni.logger.die("Container selection policy (Macaroni.Container.policy) is not set")
                }

                if let value: Value? = findPolicy.resolve(for: instance, option: alternative?.name) {
                    instance[keyPath: storageKeyPath].isResolved = true
                    instance[keyPath: storageKeyPath].storage = value as AnyObject
                    return value
                } else {
                    instance[keyPath: storageKeyPath].isResolved = true
                    instance[keyPath: storageKeyPath].storage = nil
                    return nil
                }
            }
        }
        set { /* compiler needs this. We do not. */ }
    }
}
