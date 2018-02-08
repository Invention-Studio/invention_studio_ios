//
//  EquipmentVC.swift
//  invention-studio-ios
//
//  Created by Nick's Creative Studio on 1/26/18.
//  Copyright © 2018 Invention Studio at Georgia Tech. All rights reserved.
//

import UIKit

class EquipmentVC: UIViewController, UITableViewDataSource, UITableViewDelegate, UIPickerViewDataSource, UIPickerViewDelegate, UITextViewDelegate {

    @IBOutlet weak var segmentContainer: UIView!
    @IBOutlet weak var segmentControl: UISegmentedControl!

    @IBOutlet weak var informationView: UIView!
    @IBOutlet weak var statusIcon: UIView!
    @IBOutlet weak var statusLabel: UILabel!
    
    @IBOutlet weak var reportProblemTableView: UITableView!

    private let toolBrokenHeaders = ["Your Name", "Tool", "Problem", "Comments"]
    private let toolBrokenPrototypes = [["namePrototype"],
                                ["pickerHeaderPrototype", "pickerDropdownPrototype"],
                                ["commentsPrototype"]]
    private let toolBrokenCells = [["Your Name"],
                           ["Problem", "ProblemDropdown"],
                           ["Comments"]]

    private var currentDropdownHeader: IndexPath? = nil
    private var currentDropdown: IndexPath? = nil

    private var toolGroupPicker: UIPickerView = UIPickerView()
    private var toolPicker: UIPickerView = UIPickerView()
    private var problemPicker: UIPickerView = UIPickerView()
    private var pickerSelections = ["Problem": ""]

    var name = "Nick Rupert"
    var pickerValues = ["Problem": ["Nozzle Not Extruding", "Bed Shifted"]]

    private var _status: Tool.Status = Tool.Status.AVAILABLE
    var status: Tool.Status {
        get {
            return _status
        }
        set {
            _status = newValue
            self.statusLabel.text = _status.rawValue

            switch(_status) {
            case .AVAILABLE:
                self.statusIcon.backgroundColor = UIColor(named: "StatusColorAvailable")
            case .INUSE:
                self.statusIcon.backgroundColor = UIColor(named: "StatusColorInUse")
            case .DOWN:
                self.statusIcon.backgroundColor = UIColor(named: "StatusColorDown")
            case .UNKNOWN:
                self.statusIcon.backgroundColor = UIColor(named: "StatusColorUnknown")
            }
        }
    }
    var segmentViews = Array<UIView>()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWasShown(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)

        self.segmentViews.append(informationView)
        self.segmentViews.append(reportProblemTableView)

        for picker in pickerSelections.keys {
            pickerSelections[picker] = pickerValues[picker]![0]
        }
    }

    override func viewDidLayoutSubviews() {
        let line = CAShapeLayer()
        let linePath = UIBezierPath()
        linePath.move(to: CGPoint(x: segmentContainer.frame.minX, y: segmentContainer.frame.maxY))
        linePath.addLine(to: CGPoint(x: segmentContainer.frame.maxX, y: segmentContainer.frame.maxY))
        line.path = linePath.cgPath
        line.strokeColor = UIColor(named: "IS_AccentSecondary")?.cgColor
        line.lineWidth = 0.5
        segmentContainer.layer.addSublayer(line)

        status = Tool.Status.AVAILABLE
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func segmentChanged(_ sender: UISegmentedControl) {
        for (i, view) in segmentViews.enumerated() {
            if i == sender.selectedSegmentIndex {
                view.isHidden = false
            } else {
                view.isHidden = true
            }
        }
    }

    //MARK: - Table View Data Source/Delegate

    func numberOfSections(in tableView: UITableView) -> Int {
        return toolBrokenPrototypes.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return toolBrokenPrototypes[section].count
    }


    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return toolBrokenHeaders[section]
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let prototype = toolBrokenPrototypes[indexPath.section][indexPath.row]
        if prototype == "pickerDropdownPrototype" {
            if indexPath == currentDropdown {
                return 216
            }
            return 0
        } else if prototype == "commentsPrototype" {
            return 216
        }
        return 44
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let prototype = toolBrokenPrototypes[indexPath.section][indexPath.row]
        let cellName = toolBrokenCells[indexPath.section][indexPath.row]
        switch prototype {
        case "namePrototype":
            let cell = tableView.dequeueReusableCell(withIdentifier: prototype, for: indexPath) as! FeedbackNameCell
            cell.anonymousSwitch.addTarget(self, action: #selector(anonymousSwitchChanged), for: UIControlEvents.valueChanged)
            if cell.anonymousSwitch.isOn {
                cell.titleLabel?.textColor = UIColor(named: "IS_Title")
                cell.titleLabel?.text = name
            } else {
                cell.titleLabel?.textColor = UIColor(named: "IS_Text")
                cell.titleLabel?.text = "John Doe"
            }
            return cell
        case "pickerHeaderPrototype":
            let cell = tableView.dequeueReusableCell(withIdentifier: prototype, for: indexPath) as! FeedbackPickerHeaderCell
            cell.textLabel?.text = cellName
            cell.detailTextLabel?.text = pickerSelections[cellName]

            if indexPath == currentDropdownHeader {
                print("\nSUCCESS\n")
                cell.detailTextLabel?.textColor = UIColor(named: "IS_AccentPrimary")
            } else {
                cell.detailTextLabel?.textColor = UIColor(named: "IS_Title")
            }
            return cell
        case "pickerDropdownPrototype":
            let cell = tableView.dequeueReusableCell(withIdentifier: prototype, for: indexPath) as! FeedbackPickerDropdownCell
            switch cellName {
            case "ProblemDropdown":
                problemPicker = cell.pickerView
                problemPicker.dataSource = self
                problemPicker.delegate = self
                cell.pickerView.selectRow(pickerValues["Problem"]!.index(of: pickerSelections["Problem"]!)!, inComponent: 0, animated: false)
            default:
                break
            }
            return cell
        case "commentsPrototype":
            let cell = tableView.dequeueReusableCell(withIdentifier: prototype, for: indexPath) as! FeedbackCommentsCell
            cell.commentBox.delegate = self
            return cell
        default:
            return UITableViewCell()
        }
    }

    //MARK: - Picker View Delegate

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if pickerView == self.problemPicker {
            return pickerValues["Problem"]!.count
        } else {
            return 0
        }
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if pickerView == self.problemPicker {
            return pickerValues["Problem"]?[row]
        } else {
            return nil
        }
    }

    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        if pickerView == self.problemPicker {
            return NSAttributedString(string:(pickerValues["Problem"]?[row])!, attributes: [NSAttributedStringKey.foregroundColor : UIColor(named: "IS_Title")!])
        } else {
            return nil
        }
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let title = self.pickerView(pickerView, titleForRow: row, forComponent: component)
        if pickerView == self.problemPicker {
            self.pickerSelections["Problem"] = title
        }
        reportProblemTableView.reloadData()
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let prototype = toolBrokenPrototypes[indexPath.section][indexPath.row]
        let oldDropdownSection : Int? = currentDropdown?.section
        if prototype == "pickerHeaderPrototype" {
            if indexPath == currentDropdownHeader {
                currentDropdownHeader = nil
                currentDropdown = nil
            } else {
                currentDropdownHeader = indexPath
                currentDropdown = IndexPath(row: indexPath.row + 1, section: indexPath.section)
            }
            if oldDropdownSection != nil && oldDropdownSection != indexPath.section {
                tableView.reloadSections([oldDropdownSection!], with: UITableViewRowAnimation.automatic)
            }
            tableView.reloadSections([indexPath.section], with: UITableViewRowAnimation.automatic)
        }
    }

    // MARK: - Supporting Functions

    @objc func anonymousSwitchChanged() {
        reportProblemTableView.reloadData()
    }

    @objc func dismissKeyboard() {
        view.endEditing(true)
        let contentInsets = UIEdgeInsets.zero
        UIView.animate(withDuration: 0.3) {
            self.reportProblemTableView.contentInset = contentInsets
            self.reportProblemTableView.scrollIndicatorInsets = contentInsets
        }
    }

    @objc func keyboardWasShown(_ notification : Notification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            reportProblemTableView.contentInset = UIEdgeInsetsMake(0, 0, keyboardSize.height, 0)
            reportProblemTableView.contentOffset = CGPoint(x: 0, y:keyboardSize.height)
        }
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
