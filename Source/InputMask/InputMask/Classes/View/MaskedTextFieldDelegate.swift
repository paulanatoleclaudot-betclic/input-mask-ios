//
//  MaskedTextFieldDelegate.swift
//  InputMask
//
//  Created by Egor Taflanidi on 17.08.28.
//  Copyright © 28 Heisei Egor Taflanidi. All rights reserved.
//

import Foundation
import UIKit


/**
 ### MaskedTextFieldDelegateListener
 
 Allows clients to obtain value extracted by the mask from user input.
 
 Provides callbacks from listened UITextField.
 */
@objc public protocol MaskedTextFieldDelegateListener: UITextFieldDelegate {
    
    /**
     Callback to return extracted value and to signal whether the user has complete input.
     */
    @objc optional func textField(
        _ textField: UITextField,
        didFillMandatoryCharacters complete: Bool,
        didExtractValue value: String
    )
}


/**
 ### MaskedTextFieldDelegate
 
 UITextFieldDelegate, which applies masking to the user input.
 
 Might be used as a decorator, which forwards UITextFieldDelegate calls to its own listener.
 */
@IBDesignable
open class MaskedTextFieldDelegate: NSObject, UITextFieldDelegate {
    
    private var _maskFormat:            String
    private var _autocomplete:          Bool
    private var _autocompleteOnFocus:   Bool
    private var _defaultAttribues = [NSAttributedStringKey: Any]()
    private var _oldCaretPosition = 0
    private var _fieldValue = ""
    
    public var mask: Mask
    open var strongPlaceholder: NSAttributedString?
    
    
    @IBInspectable public var maskFormat: String {
        get {
            return self._maskFormat
        }
        
        set(newFormat) {
            self._maskFormat = newFormat
            self.mask        = try! Mask.getOrCreate(withFormat: newFormat)
        }
    }
    
    @IBInspectable public var autocomplete: Bool {
        get {
            return self._autocomplete
        }
        
        set(newAutocomplete) {
            self._autocomplete = newAutocomplete
        }
    }
    
    @IBInspectable public var autocompleteOnFocus: Bool {
        get {
            return self._autocompleteOnFocus
        }
        
        set(newAutocompleteOnFocus) {
            self._autocompleteOnFocus = newAutocompleteOnFocus
        }
    }
    
    open weak var listener: MaskedTextFieldDelegateListener?
    
    public init(format: String) {
        self._maskFormat = format
        self.mask = try! Mask.getOrCreate(withFormat: format)
        self._autocomplete = false
        self._autocompleteOnFocus = false
        super.init()
    }
    
    public init(format: String, strongPlaceholder: NSAttributedString, andField field: UITextField? = nil) {
        self._maskFormat = format
        self.mask = try! Mask.getOrCreate(withFormat: format)
        self._autocomplete = false
        self._autocompleteOnFocus = false
        self.strongPlaceholder = strongPlaceholder
        if let field = field {
            _defaultAttribues.reserveCapacity(field.defaultTextAttributes.count)
            for attribute in field.defaultTextAttributes {
                _defaultAttribues[NSAttributedStringKey(rawValue: attribute.key)] = attribute.value
            }
        }
        
        super.init()
        
        field?.attributedText = strongPlaceholder
        field?.delegate = self
    }
    
    public override convenience init() {
        self.init(format: "")
    }
    
    open func put(text: String, into field: UITextField) {
        let result: Mask.Result = self.mask.apply(
            toText: CaretString(
                string: text,
                caretPosition: text.endIndex
            ),
            autocomplete: self._autocomplete
        )
        
        field.text = result.formattedText.string
        
        let position: Int =
            result.formattedText.string.distance(from: result.formattedText.string.startIndex, to: result.formattedText.caretPosition)
        
        self.setCaretPosition(position, inField: field)
        self.listener?.textField?(
            field,
            didFillMandatoryCharacters: result.complete,
            didExtractValue: result.extractedValue
        )
    }
    
    /**
     Maximal length of the text inside the field.
     
     - returns: Total available count of mandatory and optional characters inside the text field.
     */
    open func placeholder() -> String {
        return self.mask.placeholder()
    }
    
    /**
     Minimal length of the text inside the field to fill all mandatory characters in the mask.
     
     - returns: Minimal satisfying count of characters inside the text field.
     */
    open func acceptableTextLength() -> Int {
        return self.mask.acceptableTextLength()
    }
    
    /**
     Maximal length of the text inside the field.
     
     - returns: Total available count of mandatory and optional characters inside the text field.
     */
    open func totalTextLength() -> Int {
        return self.mask.totalTextLength()
    }
    
    /**
     Minimal length of the extracted value with all mandatory characters filled.
     
     - returns: Minimal satisfying count of characters in extracted value.
     */
    open func acceptableValueLength() -> Int {
        return self.mask.acceptableValueLength()
    }
    
    /**
     Maximal length of the extracted value.
     
     - returns: Total available count of mandatory and optional characters for extracted value.
     */
    open func totalValueLength() -> Int {
        return self.mask.totalValueLength()
    }
    
    // MARK: - UITextFieldDelegate
    
    open func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String) -> Bool {
        
        let extractedValue: String
        let complete:       Bool
        
        if isDeletion(
            inRange: range,
            string: string
            ) {
            (extractedValue, complete) = self.deleteText(inRange: range, inField: textField)
        } else {
            (extractedValue, complete) = self.modifyText(inRange: range, inField: textField, withText: string)
        }
        
        _fieldValue = extractedValue
        
        self.listener?.textField?(
            textField,
            didFillMandatoryCharacters: complete,
            didExtractValue: extractedValue
        )
        
        let _ = self.listener?.textField?(textField, shouldChangeCharactersIn: range, replacementString: string)
        
        return false
    }
    
    open func deleteText(
        inRange range: NSRange,
        inField field: UITextField
        ) -> (String, Bool) {
        
        let inText = range.location >= _fieldValue.count ? field.text : _fieldValue
        let text: String = self.replaceCharacters(
            inText: inText,
            range: range,
            withCharacters: ""
        )
        
        let result: Mask.Result = self.mask.apply(
            toText: CaretString(
                string: text,
                caretPosition: text.index(text.startIndex, offsetBy: range.location)
            ),
            autocomplete: false
        )
        
        field.text = result.formattedText.string
        appendStrongPlaceholderIfNeeded(toField: field)
        self.setCaretPosition(range.location, inField: field)
        
        return (result.extractedValue, result.complete)
    }
    
    open func modifyText(
        inRange range: NSRange,
        inField field: UITextField,
        withText text: String
        ) -> (String, Bool) {
        
        let inText = range.location > _fieldValue.count ? field.text : _fieldValue
        let updatedText: String = self.replaceCharacters(
            inText: inText,
            range: range,
            withCharacters: text
        )
        
        let result: Mask.Result = self.mask.apply(
            toText: CaretString(
                string: updatedText,
                caretPosition: updatedText.index(updatedText.startIndex, offsetBy: self.caretPosition(inField: field) + text.count)
            ),
            autocomplete: self.autocomplete
        )
        
        field.text = result.formattedText.string
        appendStrongPlaceholderIfNeeded(toField: field)
        
        let position: Int =
            result.formattedText.string.distance(from: result.formattedText.string.startIndex, to: result.formattedText.caretPosition)
        self.setCaretPosition(position, inField: field)
        
        return (result.extractedValue, result.complete)
    }
    
    // We do get attributes from strongPlaceholder attributed string and apply them to the strongPlaceholder substring
    public func appendStrongPlaceholderIfNeeded(toField field: UITextField) {
        guard let strongPlaceholder = strongPlaceholder else {
            return
        }
        
        let startIndex = strongPlaceholder.string.index(strongPlaceholder.string.startIndex,
                                                        offsetBy: caretPosition(inField: field))
        let substring = String(strongPlaceholder.string[startIndex...])
        let attributedString = NSMutableAttributedString(string: (field.text ?? "") + substring)
        let strongPlaceholderAttributes = strongPlaceholder.attributes(at: 0,
                                                                       longestEffectiveRange: nil,
                                                                       in: NSRange(location: 0, length: strongPlaceholder.length))
        let substringRange = (attributedString.string as NSString).range(of: substring)
        if let userEntry = field.text {
            let firstSubstringRange = (attributedString.string as NSString).range(of: userEntry)
            attributedString.addAttributes(_defaultAttribues, range: firstSubstringRange)
        }
        
        attributedString.addAttributes(strongPlaceholderAttributes, range: substringRange)
        field.attributedText = attributedString
    }
    
    open func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        return self.listener?.textFieldShouldBeginEditing?(textField) ?? true
    }
    
    open func textFieldDidBeginEditing(_ textField: UITextField) {
        self.setCaretPosition(_oldCaretPosition, inField: textField)
        if self._autocompleteOnFocus && textField.text!.isEmpty {
            let _ = self.textField(
                textField,
                shouldChangeCharactersIn: NSMakeRange(0, 0),
                replacementString: ""
            )
        }
        self.listener?.textFieldDidBeginEditing?(textField)
    }
    
    open func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        return self.listener?.textFieldShouldEndEditing?(textField) ?? true
    }
    
    open func textFieldDidEndEditing(_ textField: UITextField) {
        self.listener?.textFieldDidEndEditing?(textField)
    }
    
    open func textFieldShouldClear(_ textField: UITextField) -> Bool {
        let shouldClear: Bool = self.listener?.textFieldShouldClear?(textField) ?? true
        if shouldClear {
            let result: Mask.Result = self.mask.apply(
                toText: CaretString(
                    string: "",
                    caretPosition: "".endIndex
                ),
                autocomplete: self.autocomplete
            )
            self.listener?.textField?(
                textField,
                didFillMandatoryCharacters: result.complete,
                didExtractValue: result.extractedValue
            )
        }
        return shouldClear
    }
    
    open func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return self.listener?.textFieldShouldReturn?(textField) ?? true
    }
    
    open override var debugDescription: String {
        get {
            return self.mask.debugDescription
        }
    }
    
    open override var description: String {
        get {
            return self.debugDescription
        }
    }
    
    open func setCaretToOldPosition(inField field: UITextField) {
        setCaretPosition(_oldCaretPosition, inField: field)
    }
}

internal extension MaskedTextFieldDelegate {
    
    func isDeletion(inRange range: NSRange, string: String) -> Bool {
        return 0 < range.length && 0 == string.count
    }
    
    func replaceCharacters(inText text: String?, range: NSRange, withCharacters newText: String) -> String {
        if let text = text {
            if 0 < range.length && (range.length + range.location) <= text.count {
                let result = NSMutableString(string: text)
                result.replaceCharacters(in: range, with: newText)
                return result as String
            } else {
                let result = NSMutableString(string: text)
                result.insert(newText, at: range.location)
                return result as String
            }
        } else {
            return ""
        }
    }
    
    func caretPosition(inField field: UITextField) -> Int {
        // Workaround for non-optional `field.beginningOfDocument`, which could actually be nil if field doesn't have focus
        guard field.isFirstResponder
            else {
                return field.text?.count ?? 0
        }
        
        if let range: UITextRange = field.selectedTextRange {
            let selectedTextLocation: UITextPosition = range.start
            return field.offset(from: field.beginningOfDocument, to: selectedTextLocation)
        } else {
            return 0
        }
    }
    
    func setCaretPosition(_ position: Int, inField field: UITextField) {
        // Workaround for non-optional `field.beginningOfDocument`, which could actually be nil if field doesn't have focus
        guard field.isFirstResponder
            else {
                _oldCaretPosition = position
                return
        }
        
        
        if position > field.text!.count {
            return
        }
        
        let from: UITextPosition = field.position(from: field.beginningOfDocument, offset: position)!
        let to:   UITextPosition = field.position(from: from, offset: 0)!

        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()) {
            field.selectedTextRange = field.textRange(from: from, to: to)
            _oldCaretPosition = position
        }
    }
}
