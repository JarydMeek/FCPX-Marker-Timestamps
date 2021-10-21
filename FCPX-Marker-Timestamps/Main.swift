//
//  ContentView.swift
//  FCPX-Marker-Timestamps
//
//  Created by Jaryd Meek on 6/2/21.
//

import SwiftUI

//Handler to actually process the FCPX XML File
//I could treat this as an actual xml file, but in this case since the xml is so basic, it will be faster to just process it as a string.
class dataHandler {
    //Storage for markers
    var markers:[marker] = []
    
    //Needed Project File Information
    struct Project {
        var projectName:String = "No Project Selected"
        var frameRate: Double = 0
        var fullDuration: String = ""
        
        var maxLength: String = ""
        var hours: Int = 0
        var mins: Int = 0
        var seconds: Int = 0
        var frames: Int = 0
        var markers:[marker] = []
        
        var finalString:String = ""
    }
    //store data about each marker
    struct marker: Equatable {
        var hours:Int = 0
        var minutes:Int = 0
        var seconds:Int = 0
        var frames:Int = 0
        var name:String = ""
        var string:String = ""
        let id = UUID()
        
    }
    
    //A lot of the general drop-frame logic for this function came from here
    //http://www.andrewduncan.net/timecodes/
    
    //drop frame math is hard.
    
    //converts frame number to hours, mins, seconds, and frames
    func dropFrameMath(inFrames: Int, inRate: Double) -> (Int, Int, Int, Int){
        let rawFrames = inFrames
        let roundedFrameRate = Int(inRate.rounded())
        var finalFrames: Double
        if inRate != inRate.rounded() {
            
            let tenMins = Int(rawFrames / (600 * roundedFrameRate))
            let mins = Int(rawFrames / (60 * roundedFrameRate))
            
            let addedFrames = (2 * mins) + (-2 * tenMins)
            
            finalFrames = Double(rawFrames + addedFrames)
        } else {
            finalFrames = Double(rawFrames)
        }
        
        let hours = Int((((finalFrames / Double(roundedFrameRate)) / 60) / 60).truncatingRemainder(dividingBy: 60))
        let minutes = Int(( (finalFrames / Double(roundedFrameRate)) / 60).truncatingRemainder(dividingBy: 60))
        let seconds = Int((finalFrames / Double(roundedFrameRate)).truncatingRemainder(dividingBy: 60))
        let frames = Int(finalFrames.truncatingRemainder(dividingBy: Double(roundedFrameRate)))
        
        return (hours,minutes,seconds,frames)
        
    }
    
    //divides two numbers ina string given in the fcpxml file
    func divideNums(input: String) -> Double {
        if input == "0" {
            return 0
        }
        var firstNumStr = input[...input.firstIndex(of: "/")!]
        var secondNumStr = input[input.firstIndex(of: "/")!...]
        firstNumStr.removeLast()
        secondNumStr.removeFirst()
        if let firstNum = Double(firstNumStr), let secondNum = Double(secondNumStr) {
            return firstNum/secondNum
        } else {
            return -1
        }
    }
    
    func openFile(URL: String, project: inout Project) -> Bool {
        
        //Try to open the file
        if let contents = try? String(contentsOfFile: String(URL.dropFirst(7))) {
            //Load Project Name
            var current = contents[...]
            if let range = contents.range(of: "project name=\"") {
                project.projectName = String(contents[range.upperBound...contents.index(contents[contents.index(range.upperBound, offsetBy: 1)...].range(of: "\" uid=\"")!.lowerBound, offsetBy: -1)])
                current = contents[range.upperBound...]
            }
            var duration = ""
            //Length
            if let range = current.range(of: "<sequence duration=\"") {
                duration = String(current[range.upperBound...current.index(current[current.index(range.upperBound, offsetBy: 1)...].range(of: "s\" format=")!.lowerBound, offsetBy: -1)])
            }
            //FRAME RATE
            if let range = contents.range(of: "frameDuration") {
                let index = contents.index(range.upperBound, offsetBy: 2)
                var temp = contents[index...contents[index...].firstIndex(of: "\"")!]
                temp.removeLast(2)
                project.frameRate = (Double(round(1000*(1/(divideNums(input: (String(temp))))))/1000))
                
                //Calculate largest value we will have (length of project)
                (project.hours,project.mins,project.seconds,project.frames) = dropFrameMath(inFrames: Int((divideNums(input: duration)*project.frameRate).rounded()), inRate: project.frameRate)
                if (project.hours >= 1) {
                    project.maxLength = "h"
                    project.fullDuration =  String(format: "%02d", project.hours) + ":" + String(format: "%02d", project.mins) + ":" + String(format: "%02d", project.seconds)
                } else if (project.mins >= 1) {
                    project.maxLength = "m"
                    project.fullDuration =  String(format: "%02d", project.mins) + ":" + String(format: "%02d", project.seconds)
                } else if (project.seconds >= 1) {
                    project.maxLength = "s"
                    project.fullDuration =  String(format: "%02d", project.seconds)
                } else {
                    project.maxLength = "f"
                }
                
                //At This Point, We have the FPS and Project Name. Awesome.
                
                //Marker Time
                
                var currentPosition = contents.startIndex
                
                while contents[currentPosition...].contains("<marker start=\""){
                    if let markerPosition = contents[currentPosition...].range(of: "<marker start=\"") {
                        let markerLine = contents[markerPosition.lowerBound...contents[markerPosition.lowerBound...].range(of: "/>")!.upperBound]
                        if !markerLine.contains("completed=\"") {
                            var lines = contents[...markerPosition.lowerBound].split(separator: "\n")
                            lines.removeLast()
                            lines.reverse()
                            //find number of spaces
                            let markerSpaces = contents[contents[...markerPosition.lowerBound].range(of: "\n", options:String.CompareOptions.backwards)!.upperBound...markerPosition.lowerBound].count
                            for x in lines {
                                if let checkIndex = x.range(of: "<"){
                                    let check = x[...checkIndex.lowerBound]
                                    if check.count == markerSpaces-4 {
                                        var test:Bool = true
                                        for i in 0...markerSpaces-6{
                                            if check[check.index(check.startIndex, offsetBy: i)] != " " {
                                                test = false
                                            }

                                        }
                                        if test {
                                            //we have the container for the marker, this should be the clip that we need to base our time off of.
                                            if x.contains("offset=\"") && x.contains("start=\"") {
                                                //Offset
                                                let offsetStart = x.range(of: "offset=\"")
                                                let offsetEnd = x.index(x[offsetStart!.upperBound...].firstIndex(of: "s")!, offsetBy: -1)
                                                let offset = String(x[offsetStart!.upperBound...offsetEnd])
                                                
                                                //Start
                                                let startStart = x.range(of: "start=\"")
                                                let startEnd = x.index(x[startStart!.upperBound...].firstIndex(of: "s")!, offsetBy: -1)
                                                let start = String(x[startStart!.upperBound...startEnd])
                                                
                                                //Marker Start
                                                let markerStart = markerLine.range(of: "start=\"")
                                                let markerEnd = markerLine.index(markerLine[markerStart!.upperBound...].firstIndex(of: "s")!, offsetBy: -1)
                                                let markerInfo = String(markerLine[markerStart!.upperBound...markerEnd])
                                                
                                                //Marker Value
                                                let valueStart = markerLine.range(of: "value=\"")
                                                let valueEnd = markerLine.index(markerLine[valueStart!.upperBound...].range(of: "\"/>")!.lowerBound, offsetBy: -1)
                                                let value = String(markerLine[valueStart!.upperBound...valueEnd])
                                                
                                                // Need Offset, start and marker information
                                                let rawTimeCode = (divideNums(input: String(markerInfo)) - divideNums(input: String(start))) + divideNums(input: String(offset))
                                                var rawFrames = (rawTimeCode * project.frameRate)
                                                rawFrames.round()
                                                let (hours, mins, seconds, frames) = dropFrameMath(inFrames:Int(rawFrames), inRate: project.frameRate)
                                                
                                                var tempMarker = marker()
                                                tempMarker.hours = hours
                                                tempMarker.minutes = mins
                                                tempMarker.seconds = seconds
                                                tempMarker.frames = frames
                                                tempMarker.name = String(value)
                                                
                                                project.markers.append(tempMarker)
                                            } else if x.contains("offset=\"") {
                                                //only need offset information
                                                
                                                //Offset
                                                let offsetStart = x.range(of: "offset=\"")
                                                let offsetEnd = x.index(x[offsetStart!.upperBound...].firstIndex(of: "s")!, offsetBy: -1)
                                                let offset = String(x[offsetStart!.upperBound...offsetEnd])

                                                //Marker Value
                                                let valueStart = markerLine.range(of: "value=\"")
                                                let valueEnd = markerLine.index(markerLine[valueStart!.upperBound...].range(of: "\"/>")!.lowerBound, offsetBy: -1)
                                                let value = String(markerLine[valueStart!.upperBound...valueEnd])
                                                
                                                var rawFrames = (divideNums(input: offset) * project.frameRate)
                                                rawFrames.round()
                                                let (hours, mins, seconds, frames) = dropFrameMath(inFrames:Int(rawFrames), inRate: project.frameRate)
                                                
                                                var tempMarker = marker()
                                                tempMarker.hours = hours
                                                tempMarker.minutes = mins
                                                tempMarker.seconds = seconds
                                                tempMarker.frames = frames
                                                tempMarker.name = String(value)
                                                
                                                project.markers.append(tempMarker)
                                                
                                            }
                                            break
                                        }
                                    }
                                }
                            }

                        }
                        currentPosition = contents[markerPosition.lowerBound...].range(of: "/>")!.upperBound
                        
                        
                        
                    }
                }
                
                
                
            } else {
                return false
            }
            return true
        } else {
            return false
        }
    }
    
func getDataString(URL: String, frames: Bool) -> Project {
    //Create a new project
    var currProject = Project()
    var storage = ""
    
    if openFile(URL: URL, project: &currProject) {
        var duplicateCheck:[String] = []
        for x in currProject.markers {
            if duplicateCheck.contains(x.name){
                duplicateCheck.removeAll { $0 == x.name }
                for y in currProject.markers{
                    if y.name == x.name {
                        if let idx = currProject.markers.firstIndex(of: y) {
                            currProject.markers.remove(at: idx)
                        }
                        break
                    }
                }
            }
            duplicateCheck.append(x.name)
        }
        var tempString = ""
        var index = 0
        while index < currProject.markers.count {
            var marker = currProject.markers[index]
            tempString = ""
            if currProject.maxLength == "h" {
                tempString += String(format: "%02d", marker.hours) + ":" + String(format: "%02d", marker.minutes) + ":" +  String(format: "%02d", marker.seconds)
            } else if currProject.maxLength == "m" {
                tempString += String(format: "%02d", marker.minutes) + ":" + String(format: "%02d", marker.seconds)
            } else if currProject.maxLength == "s" {
                tempString += String(format: "%02d", marker.seconds)
            }
            
            if frames && currProject.frameRate == (currProject.frameRate.rounded()){
                tempString += ":" + String(format: "%02d", marker.frames)
            } else if frames && currProject.frameRate != (currProject.frameRate.rounded()){
                tempString += ";" + String(format: "%02d", marker.frames)
            }
            
            tempString += " - \(marker.name)"
            storage += tempString + "\n"
            marker.string = tempString
            currProject.markers[index] = marker
            index += 1
        }
        currProject.finalString = storage
        return currProject
    } else {
        return Project(finalString: "NULL")
    }
}
}


//Button Style to make life easier
struct MainButton: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .foregroundColor(Color.white)
            .background(configuration.isPressed ? Color.gray : Color.accentColor)
            .cornerRadius(6)
    }
}



//Instantiate the XML Handler



struct Main: View {
    @State var showFilePicker = false
    @State var openURL:String = "/No File Selected"
    
    @State var addFrames:Bool = false
    @State var data = dataHandler()
    
    
    func openFile() {
        let open = NSOpenPanel()
        open.canChooseFiles = true
        open.canChooseDirectories = false
        open.allowsMultipleSelection = false
        open.allowedFileTypes = ["fcpxml"]
        open.begin { response in
            if response == NSApplication.ModalResponse.OK, let fileUrl = open.url {
                openURL = fileUrl.absoluteString.removingPercentEncoding!
            }
        }
    }
    
    //MAIN VIEW
    var body: some View {
        GeometryReader { metrics in
            VStack {
                HStack{
                    Spacer()
                    VStack{
                        Image("marker")
                            .resizable()
                            .foregroundColor(Color("mainBlue"))
                            .frame(width:50, height:50)
                        Text("FCPX Marker To Timestamps")
                            .padding()
                            .multilineTextAlignment(.center)
                            .font(.largeTitle)
                        HStack{
                            Text(openURL[openURL.index(openURL.lastIndex(of: "/")!, offsetBy: 1)...])
                            
                            Spacer()
                                .frame(width: 25)
                            Button(action: {
                                openFile()
                            }, label: {
                                Text("Select File")
                                    .padding(.top, 5)
                                    .padding(.bottom, 5)
                                    .padding(.leading, 15)
                                    .padding(.trailing, 15)
                            }).buttonStyle(MainButton())
                        }
                        .padding([.top, .bottom, .trailing], 5)
                        .padding([.leading], 15)
                        .background(Color.white.opacity(0.5))
                        .cornerRadius(5)
                    }
                    Spacer()
                }
                Spacer().frame(height: 25)
                if let currentProject = data.getDataString(URL: openURL, frames: addFrames) {//If file is selected, show extra options
                    if currentProject.finalString != "NULL"{
                        VStack{
                            HStack{
                                VStack{
                                    Text("Project Name:")
                                    Text(currentProject.projectName)
                                }
                                .padding([.top, .bottom], 5)
                                .padding([.leading, .trailing], 15)
                                .background(Color.white.opacity(0.5))
                                .cornerRadius(5)
                                Spacer()
                                    .frame(width:25)
                                VStack{
                                    Text("Project Duration:")
                                    Text(currentProject.fullDuration)
                                }
                                .padding([.top, .bottom], 5)
                                .padding([.leading, .trailing], 15)
                                .background(Color.white.opacity(0.5))
                                .cornerRadius(5)
                                Spacer()
                                    .frame(width:25)
                                Toggle(isOn: $addFrames) {
                                    Text("Show Frames")
                                }
                                .frame(height: 32)
                                .toggleStyle(CheckboxToggleStyle())
                                .padding([.top, .bottom], 5)
                                .padding([.leading, .trailing], 15)
                                .background(Color.white.opacity(0.5))
                                .cornerRadius(5)
                                
                            }
                            ZStack(alignment: .bottomTrailing){
                                List {
                                    ForEach(currentProject.markers, id: \.id) { marker in
                                        Text(marker.string).foregroundColor(Color.black)
                                            .font(Font.custom("Roboto-Mono", size: 16))
                                        
                                    }
                                }.background(Color.white.opacity(0.5))
                                VStack{
                                    Spacer()
                                    Button(action: {
                                        let pasteboard = NSPasteboard.general
                                        pasteboard.clearContents()
                                        pasteboard.setString(currentProject.finalString, forType: .string)
                                    }){
                                        Image(systemName: "doc.on.clipboard")
                                            .font(.system(size: 25))
                                            .frame(width: 50, height: 50)
                                            .foregroundColor(Color.white)
                                            .background(Color.accentColor)
                                            .clipShape(Circle())
                                    }.buttonStyle(PlainButtonStyle())
                                }
                                .frame(width: 50, height: 50)
                                .help("Copy Markers To Clipboard")
                                .padding(15)
                            }
                        }
                    }
                }
            }.padding(20)
        }
        .background(LinearGradient(gradient: Gradient(colors: [.clear, Color("mainBlue")]), startPoint: .top, endPoint: .bottom))
        .accentColor(Color("mainBlue"))
    }
}

struct Main_Preview: PreviewProvider {
    static var previews: some View {
        Main()
    }
}
