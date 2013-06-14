# encoding: utf-8
require 'net/http'
require 'rexml/document'

class OnlineWorkerController < ApplicationController
    
  def get_status
    url  = params[ :url ]
    port = params[ :port ]    
    
    session[:of_last_used_url] = url 
    session[:of_last_used_port] = port 
    
    doc = get_document(url, port)

    domain_node = doc.elements[ 'soapenv:Envelope/soapenv:Body/typ:Domain' ]
    @domain = Container.new
    @domain.name = domain_node.text( 'Name' )
    
    domain_node.each_element( 'Server' ) do |server_node|  
    
      if server_node.name != 'Name'
        server = Container.new
        @domain.servers ||= []
        @domain.servers << server
      
        server.name = server_node.text( 'Name' )
        server.current_heap = server_node.text( 'JVMInfo/HeapMemoryUsed')
        server.max_heap = server_node.text( 'JVMInfo/HeapMemoryMax')
        server.start_time = DateTime.strptime( server_node.text( 'JVMInfo/StartTime'), "%Y-%m-%dT%H:%M" )
      
        server_node.each_element( 'Worker' ) do |worker_node|  
            
          worker = Container.new
          server.workers ||= []
          server.workers << worker
            
          worker.identifier = worker_node.text( 'Identifier' )
          worker.thread_state = worker_node.text( 'ThreadState')
          worker.worker_state = worker_node.text( 'WorkerState')

          failure = 0
          str = worker_node.text( 'CurrentProcessing/Failure' )    
          failure += str.to_i if str
          str = worker_node.text( 'CompleteProcessing/Failure' )
          failure += str.to_i if str
          worker.failures = failure
          
          success = 0
          worker_node.each_element( 'CurrentProcessing/Success' ) do |e|
            str = e.text( 'MessageCount' )
            success += str.to_i if str  
          end
          worker_node.each_element( 'CompleteProcessing/Success' ) do |e|
            str = e.text( 'MessageCount' )
            success += str.to_i if str  
          end    
          worker.successful = success

          a1 = false
          level = 0
          
          worker.stack_trace ||= []
          worker_node.each_element( 'StackTrace/Stack' ) do |e|
            
            if ( e.text == 'de.otto.noa.standard.saf.onlineframework.worker.OFWorkerTxGrp.run' ||                 
                 e.text == 'de.otto.noa.standard.saf.database.grp.TxGrp.run' || 
                 e.text == 'de.otto.noa.standard.saf.onlineframework.worker.OFWorkerTxGrp.retry' || 
                 e.text == 'de.otto.noa.standard.saf.database.grp.TxGrp.retry' ||
                 e.text == 'de.otto.noa.standard.saf.onlineframework.worker.OFWorkerTxGrp.onMsg' )
              
                if a1 != true
                  a1 = true                  
                  level += 1
               end
            else
              if a1 == true
                a1 = false 
                worker.stack_trace << '-----------------------------------'
                worker.stack_trace << "Gruppenverarbeitung Level #{level}; Das Divide wird ausgeblendet !!"
                worker.stack_trace << '-----------------------------------'
              else
                worker.stack_trace << e.text
              end  
            end     
          end
        end
      end      
    end
  end
  
  private 
  
  def get_document( url, port )

  session = Net::HTTP.new( url, port )

  response = session.send_request( 'POST', 'onlinejournal/Onlineframework', '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:typ="http://noa.otto.de/onlinejournal/webservice/onlineframework/types">
     <soapenv:Header/>
     <soapenv:Body>
        <typ:DomainStatusIn>?</typ:DomainStatusIn>
     </soapenv:Body>
  </soapenv:Envelope>', { 'Content-Type' => 'text/xml;charset=UTF-8' } )

   REXML::Document.new( response.body ) 
  end
  
end

#get_status