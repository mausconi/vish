# Copyright 2011-2012 Universidad Politécnica de Madrid and Agora Systems S.A.
#
# This file is part of ViSH (Virtual Science Hub).
#
# ViSH is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# ViSH is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with ViSH.  If not, see <http://www.gnu.org/licenses/>.
 
####################
## IMS QTI 2.1 Management
####################

require 'builder'

class IMSQTI

  def self.createQTI(filePath,fileName,qjson)
    require 'zip/zip'
    require 'zip/zipfilesystem'

    t = File.open("#{filePath}#{fileName}.zip", 'w')

    Zip::ZipOutputStream.open(t.path) do |zos|
      case qjson["quiztype"]
      when "truefalse"
        for i in 0..((qjson["choices"].size)-1)
          qti_tf = IMSQTI.generate_QTITF(qjson,i)
          zos.put_next_entry(fileName +"_" + i.to_s + ".xml")
          zos.print qti_tf.target!()
        end
        main_tf = IMSQTI.generate_mainQTIMC(qjson,fileName)
        zos.put_next_entry(fileName + ".xml")
        zos.print main_tf

      when "multiplechoice"
        qti_mc = IMSQTI.generate_QTIMC(qjson)
        zos.put_next_entry(fileName + ".xml")
        zos.print qti_mc.target!()

      when "openAnswer"
        qti_open = IMSQTI.generate_QTIopenAnswer(qjson)
        zos.put_next_entry(fileName + ".xml")
        zos.print qti_open.target!()

      when "sorting"
        qti_ordered = IMSQTI.generate_QTIOrdered(qjson)
        zos.put_next_entry(fileName + ".xml")
        zos.print qti_ordered.target!()
      else
      end

      xml_truemanifest = IMSQTI.generate_qti_manifest(qjson,fileName)
      zos.put_next_entry("imsmanifest.xml")
      zos.print xml_truemanifest

      t.close
    end
  end

  def self.generate_QTITF(qjson,index)
    myxml = ::Builder::XmlMarkup.new(:indent => 2)
    myxml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
    
    myxml.assessmentItem("xmlns"=>"http://www.imsglobal.org/xsd/imsqti_v2p1", "xmlns:xsi"=>"http://www.w3.org/2001/XMLSchema-instance", "xsi:schemaLocation"=>"http://www.imsglobal.org/xsd/imsqti_v2p1  http://www.imsglobal.org/xsd/qti/qtiv2p1/imsqti_v2p1.xsd","identifier"=>"choiceMultiple", "title"=>"Prueba", "timeDependent"=>"false", "adaptive" => "false") do
      
      myxml.responseDeclaration("identifier"=>"RESPONSE", "cardinality" => "single", "baseType" => "identifier") do
        
        myxml.correctResponse() do
          if qjson["choices"][index]["answer"] == true 
            myxml.value("A0")
          else
            myxml.value("A1")
          end
        end
        
        myxml.mapping("lowerBound" => "-1", "upperBound"=>"1", "defaultValue"=>"0") do
          if qjson["choices"][index]["answer"] == true
            myxml.mapEntry("mapKey"=>"A0", "mappedValue"=> 1)
            myxml.mapEntry("mapKey"=> "A1", "mappedValue"=> -1)
          else
            myxml.mapEntry("mapKey"=>"A0", "mappedValue"=> -1)
            myxml.mapEntry("mapKey"=> "A1", "mappedValue"=> 1)
          end             
        end

      end

      myxml.outcomeDeclaration("identifier"=>"SCORE", "cardinality"=>"single", "baseType"=>"float") do
      end

      myxml.itemBody() do
        myxml.choiceInteraction("responseIdentifier"=>"RESPONSE", "shuffle" => "false", "maxChoices" => "1", "minChoices"=>"0") do
          myxml.prompt(qjson["question"]["value"]  + ": " + qjson["choices"][index]["value"])
          myxml.simpleChoice("True","identifier"=>"A0")
          myxml.simpleChoice("False","identifier"=>"A1") 
        end
      end

      myxml.responseProcessing()
    end

    return myxml;
  end

  def self.generate_QTIOrdered(qjson)
    myxml = ::Builder::XmlMarkup.new(:indent => 2)
    myxml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
      
    nChoices = qjson["choices"].size

    myxml.assessmentItem("xmlns"=>"http://www.imsglobal.org/xsd/imsqti_v2p1", "xmlns:xsi"=>"http://www.w3.org/2001/XMLSchema-instance", "xsi:schemaLocation"=>"http://www.imsglobal.org/xsd/imsqti_v2p1  http://www.imsglobal.org/xsd/qti/qtiv2p1/imsqti_v2p1.xsd","identifier"=>"Sorting Quiz", "title"=>"Sorting Quiz", "timeDependent"=>"false", "adaptive"=>"false") do

      identifiers= [] 
        qjson["choices"].each_with_index do |choice,i|
          identifiers.push("A" + i.to_s())
        end

        myxml.responseDeclaration("identifier"=>"RESPONSE", "cardinality" => "ordered", "baseType" => "identifier") do
          myxml.correctResponse() do
            for i in 0..((nChoices)-1)
                myxml.value(identifiers[i])
            end
          end  
        end

        myxml.outcomeDeclaration("cardinality"=>"single", "baseType"=>"identifier", "identifier"=>"FEEDBACK") do
        end
      
        myxml.itemBody() do
          myxml.orderInteraction("responseIdentifier"=>"RESPONSE", "shuffle"=>"true", "orientation"=>"vertical") do
            myxml.prompt(qjson["question"]["value"])
            for i in 0..((nChoices)-1)
                myxml.simpleChoice(qjson["choices"][i]["value"],"identifier"=> identifiers[i], "showHide" => "show")
            end
          end
        end  
      myxml.responseProcessing()
    end

    return myxml;
  end

  def self.generate_QTIopenAnswer(qjson)

    myxml = ::Builder::XmlMarkup.new(:indent => 2)
    myxml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
        
    myxml.assessmentItem("xmlns"=>"http://www.imsglobal.org/xsd/imsqti_v2p1", "xmlns:xsi"=>"http://www.w3.org/2001/XMLSchema-instance", "xsi:schemaLocation"=>"http://www.imsglobal.org/xsd/imsqti_v2p1  http://www.imsglobal.org/xsd/qti/qtiv2p1/imsqti_v2p1.xsd","identifier"=>"openAnswer", "title"=>"Open Answer Quiz", "timeDependent"=>"false", "adaptive"=>"false") do
      myxml.responseDeclaration("identifier"=>"RESPONSE", "cardinality" => "single", "baseType" => "string") do
        myxml.correctResponse() do
          myxml.value(qjson["answer"]["value"])
        end
        if qjson["selfA"] == true
          myxml.mapping("defaultValue" => "0") do
            myxml.mapEntry("mapKey" => qjson["answer"]["value"], "mappedValue" => "1")
          end
        else
        end
      end

        myxml.outcomeDeclaration("identifier"=>"SCORE", "cardinality"=>"single", "baseType"=>"float") do
        end
      
        myxml.itemBody() do
          myxml.p(qjson["question"]["value"])
            myxml.div() do
              if qjson["selfA"] == true   
                myxml.textEntryInteraction("responseIdentifier" => "RESPONSE", "expectedLength" => "40") 
              else
                myxml.extendedTextInteraction("responseIdentifier" => "RESPONSE", "expectedLength" => "120", "expectedLines" => "5") 
              end
            end
          end
        
          if qjson["selfA"] == true    
            myxml.responseProcessing("template" => "http://www.imsglobal.org/question/qti_v2p1/rptemplates/map_response")
          else
          end
      end

    return myxml;
  end

  def self.generate_QTIMC(qjson)

      myxml = ::Builder::XmlMarkup.new(:indent => 2)
      myxml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
        
      nChoices = qjson["choices"].size

      myxml.assessmentItem("xmlns"=>"http://www.imsglobal.org/xsd/imsqti_v2p1", "xmlns:xsi"=>"http://www.w3.org/2001/XMLSchema-instance", "xsi:schemaLocation"=>"http://www.imsglobal.org/xsd/imsqti_v2p1  http://www.imsglobal.org/xsd/qti/qtiv2p1/imsqti_v2p1.xsd","identifier"=>"choiceMultiple", "title"=>"Prueba", "timeDependent"=>"false", "adaptive"=>"false") do

        identifiers= [] 
        qjson["choices"].each_with_index do |choice,i|
          identifiers.push("A" + i.to_s())
        end

        if qjson["extras"]["multipleAnswer"] == false 
          card = "single"
          maxC = "1"
        else
          card = "multiple"
          maxC = "0"
        end 

        myxml.responseDeclaration("identifier"=>"RESPONSE", "cardinality" => card, "baseType" => "identifier") do
        
          vcont = 0
          myxml.correctResponse() do
            for i in 0..((nChoices)-1)
              if qjson["choices"][i]["answer"] == true 
                myxml.value(identifiers[i])
                vcont = vcont + 1
              end
            end
          end  
          
          myxml.mapping("lowerBound" => "0", "upperBound"=>"1", "defaultValue"=>"0") do
            for i in 0..((nChoices)-1)
              if qjson["choices"][i]["answer"] == true
                mappedV = 1/vcont.to_f
              else
                mappedV = 0.to_f
                #mappedV = -1/(qjson["choices"].size)
              end
              myxml.mapEntry("mapKey"=> identifiers[i], "mappedValue"=> mappedV)
            end
          end 
        end

        myxml.outcomeDeclaration("identifier"=>"SCORE", "cardinality"=>"single", "baseType"=>"float") do
        end
      
        myxml.itemBody() do
          myxml.choiceInteraction("responseIdentifier"=>"RESPONSE", "shuffle"=>"false",  "maxChoices" => maxC, "minChoices"=>"0") do
            myxml.prompt(qjson["question"]["value"])
            for i in 0..((nChoices)-1)
                myxml.simpleChoice(qjson["choices"][i]["value"],"identifier"=> identifiers[i])
            end
          end
        end
            
        myxml.responseProcessing()
      end

      return myxml;
    end

  def self.generate_MoodleQUIZXML(qjson)
    myxml = ::Builder::XmlMarkup.new(:indent => 2)
    myxml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"

    myxml.quiz do
      myxml.question("type" => "category") do
        myxml.category do
          myxml.text do
             myxml.text!("Moodle QUIZ XML export")
          end
        end
      end

      myxml.question("type" => "multichoice") do
        myxml.name do
          myxml.text do
            myxml.text!("La pregunta")
          end
        end
      end
    end
  end

  def self.generate_qti_manifest(qjson,fileName)
    identifier = "TmpIMSQTI_" + (Site.current.config["tmpJSONcount"].nil? ? "1" : Site.current.config["tmpJSONcount"].to_s)

    myxml = ::Builder::XmlMarkup.new(:indent => 2)
    myxml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
    
    myxml.manifest("identifier"=>"VISH_QUIZ_" + identifier, "xsi:schemaLocation"=>"http://www.imsglobal.org/xsd/imscp_v1p1 http://www.imsglobal.org/xsd/imscp_v1p2.xsd http://www.imsglobal.org/xsd/imsmd_v1p2 http://www.imsglobal.org/xsd/imsmd_v1p2p2.xsd http://www.imsglobal.org/xsd/imsqti_v2p1 http://www.imsglobal.org/xsd/imsqti_v2p1.xsd", "xmlns" => "http://www.imsglobal.org/xsd/imscp_v1p2","xmlns:imsqti" => "http://www.imsglobal.org/xsd/imsqti_v2p1", "xmlns:imsmd" => "http://www.imsglobal.org/xsd/imsmd_v1p2", "xmlns:xsi"=>"http://www.w3.org/2001/XMLSchema-instance") do
      
      myxml.metadata do
        myxml.schema("IMS Content")
        myxml.schemaversion("1.2")
        myxml.tag!("imsmd:lom") do
          myxml.tag!("imsmd:general") do
            myxml.tag!("imsmd:title") do
              myxml.tag!("imsmd:langstring", {"xml:lang"=>"en"}) do
                myxml.text!("Content package including QTI v2.1. items")
              end
            end
          end
          myxml.tag!("imsmd:technical") do
            myxml.tag!("imsmd:format") do
              myxml.text!("text/x-imsqti-item-xml")
            end
          end
          myxml.tag!("imsmd:rights") do
            myxml.tag!("imsmd:description") do
              myxml.tag!("imsmd:langstring", {"xml:lang"=>"en"}) do
                myxml.text!("Copyright (C) Virtual Science Hub 2014")
              end
            end
          end
        end
      end
      
      myxml.organizations do
      end

      myxml.resources do
        IMSQTI.generate_qti_resources(qjson,fileName,myxml)
      end

    end
  end

  def self.generate_mainQTIMC(qjson,fileName)
    resource_identifier = "resource-item-quiz-" + (Site.current.config["tmpJSONcount"].nil? ? "1" : Site.current.config["tmpJSONcount"].to_s)

    myxml = ::Builder::XmlMarkup.new(:indent => 2)
    myxml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"

    myxml.assessmentTest("xmlns" => "http://www.imsglobal.org/xsd/imsqti_v2p1", "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance", "xsi:schemaLocation" => "http://www.imsglobal.org/xsd/imsqti_v2p1 http://www.imsglobal.org/xsd/imsqti_v2p1.xsd", "identifier" => "TrueFalseTest", "title" => "True False Tests", "toolName"=>"VISH Editor", "toolVersion" => "2.3") do
      myxml.outcomeDeclaration("identifier" => "SCORE", "cardinality" => "single", "baseType" => "integer") do
      end
        if qjson["quiztype"] == "truefalse"
          for i in 0..((qjson["choices"].size)-1)
            myxml.assessmentItemRef("identifier" => resource_identifier + i.to_s, "href" => fileName + "_" + i.to_s + ".xml") do
            end
          end
        end
    end
  end

  def self.generate_qti_resources(qjson,fileName,myxml)
    resource_identifier = "resource-item-quiz-" + (Site.current.config["tmpJSONcount"].nil? ? "1" : Site.current.config["tmpJSONcount"].to_s)

    if qjson["quiztype"] == "truefalse"
      myxml.resource("identifier" => resource_identifier , "type"=>"imsqti_item_xmlv2p1", "href" => fileName + ".xml") do
          myxml.metadata do
            myxml.tag!("imsmd:lom") do
              myxml.tag!("imsmd:general") do
                myxml.tag!("imsmd:title") do
                  myxml.tag!("imsmd:langstring",{"xml:lang"=>"en"}) do
                    myxml.text!("TrueFalse")
                  end
                end
              end
              myxml.tag!("imsmd:technical") do
                myxml.tag!("imsmd:format") do
                  myxml.text!("text/x-imsqti-item-xml")
                end
              end
            end
            myxml.tag!("imsqti:qtiMetadata") do
              myxml.tag!("imsqti:interactionType") do
                myxml.text!("choiceInteraction")
              end
            end
          end
          myxml.file("href" => fileName + ".xml")
        end
      for i in 0..((qjson["choices"].size)-1)
        myxml.resource("identifier" => resource_identifier + i.to_s, "type"=>"imsqti_item_xmlv2p1", "href" => fileName + "_" + i.to_s + ".xml") do
          myxml.metadata do
            myxml.tag!("imsmd:lom") do
              myxml.tag!("imsmd:general") do
                myxml.tag!("imsmd:title") do
                  myxml.tag!("imsmd:langstring",{"xml:lang"=>"en"}) do
                    myxml.text!("TrueFalse")
                  end
                end
              end
              myxml.tag!("imsmd:technical") do
                myxml.tag!("imsmd:format") do
                  myxml.text!("text/x-imsqti-item-xml")
                end
              end
            end
            myxml.tag!("imsqti:qtiMetadata") do
              myxml.tag!("imsqti:interactionType") do
                myxml.text!("choiceInteraction")
              end
            end
          end
          myxml.file("href" => fileName + "_" + i.to_s + ".xml")
        end
      end
    elsif qjson["quiztype"] == "multiplechoice" || qjson["quiztype"] == "sorting" || qjson["quiztype"] == "openAnswer"
      case qjson["quiztype"]
      when "sorting"
        typeQ = "Sorting"
        typeInteraction = "Sorting Interaction"
      when "multiplechoice"
        typeQ = "MultipleChoice"
        typeInteraction = "choiceInteraction"
      when "openAnswer"
        typeQ = "OpenAnswer"
        typeInteraction = "extendedTextInteraction"
      end

      myxml.resource("identifier" => resource_identifier, "type"=>"imsqti_item_xmlv2p1", "href" => fileName + ".xml") do
        myxml.metadata do
          myxml.tag!("imsmd:lom") do
            myxml.tag!("imsmd:general") do
              myxml.tag!("imsmd:title") do
                myxml.tag!("imsmd:langstring",{"xml:lang"=>"en"}) do
                  myxml.text!(typeQ)
                end
              end
            end
            myxml.tag!("imsmd:technical") do
              myxml.tag!("imsmd:format") do
              myxml.text!("text/x-imsqti-item-xml")
              end
            end
          end
          myxml.tag!("imsqti:qtiMetadata") do
            myxml.tag!("imsqti:interactionType") do
              myxml.text!(typeInteraction)
            end
          end
        end
        myxml.file("href" => fileName + ".xml")
      end
    end
  end

end