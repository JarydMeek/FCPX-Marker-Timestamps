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
    
    struct marker {
        var hours:Int = 0
        var minutes:Int = 0
        var seconds:Int = 0
        var frames:Int = 0
        var name:String = ""
        var string:String = ""
        let id = UUID()
        
    }
    
    //A lot of the logic for this function came from here
    //http://www.andrewduncan.net/timecodes/
    
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
                
                //START VALUE
                if let range2 = contents.range(of: "<spine>") {
                    current = contents[range2.upperBound...]
                }
                if let range3 = current.range(of: " start=\"") {
                    var temp = contents[range3.upperBound...contents[range3.upperBound...].firstIndex(of: "\"")!]
                    temp.removeLast(2)
                    current = current[range3.upperBound...]
                }
                //At This Point, We have the FPS and Project Name. Awesome.
                
                //BEGIN MARKERS
                while current.contains("<marker start=\""){
                    if let markerRange = current.range(of: "<marker start=\"") {
                        
                        //Get the Reference Clip information needed for the calculation
                        let refClipRange = current[...markerRange.lowerBound].range(of:"<ref-clip name=\"",  options: String.CompareOptions.backwards)
                        let offsetRange = current[refClipRange!.upperBound...markerRange.upperBound].range(of:"offset=\"")
                        let startRange = current[refClipRange!.upperBound...markerRange.upperBound].range(of:"start=\"")
                        let offset = current[offsetRange!.upperBound...current.index(current[offsetRange!.upperBound...].firstIndex(of: "\"")!, offsetBy: -2)]
                        let start = current[startRange!.upperBound...current.index(current[startRange!.upperBound...].firstIndex(of: "\"")!, offsetBy: -2)]
                        
                        
                        //Get the information needed for the marker point calculation.
                        let endIndex = current.index(current[markerRange.upperBound...].firstIndex(of: "\"")!, offsetBy: -2)
                        let markerPoint = current[markerRange.upperBound...endIndex]
                        
                        //Get the marker name
                        let valueRange = current[markerRange.upperBound...].range(of:"value=\"")
                        let endValue = current.index(current[valueRange!.upperBound...].range(of: "\"/>")!.lowerBound, offsetBy: -1)
                        let value = current[valueRange!.upperBound...endValue]
                        
                        //We have all the information we need. Lets convert these to timecodes.
                        
                        //divide the numbers and do the drop frame math
                        //Calculate raw number
                        let rawTimeCode = (divideNums(input: String(markerPoint)) - divideNums(input: String(start))) + divideNums(input: String(offset))
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
                        //reset string for next iteration
                        current = current[endValue...]
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
