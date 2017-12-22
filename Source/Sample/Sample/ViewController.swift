//
//  ViewController.swift
//  Sample
//
//  Created by Egor Taflanidi on 17.08.28.
//  Copyright © 28 Heisei Egor Taflanidi. All rights reserved.
//

import UIKit
import InputMask


open class ViewController: UIViewController, MaskedTextFieldDelegateListener {
    
    var listener: MaskedTextFieldDelegate!
    @IBOutlet weak var field: UITextField!
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        listener = MaskedTextFieldDelegate(format: "[00]{/}[00]{/}[0000]", strongPlaceholder: "MM/JJ/AAAA", andField: field)
    }
    
    open func textField(
        _ textField: UITextField,
        didFillMandatoryCharacters complete: Bool,
        didExtractValue value: String
    ) {
        print(value)
    }
    
}
