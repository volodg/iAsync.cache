platform :ios, '8.0'
use_frameworks!

def import_pods

pod 'Result'        , :path => '../../Result-swift-2.0'
pod 'iAsync.async'  , :path => '../iAsync.async'
pod 'iAsync.utils'  , :path => '../iAsync.utils'
pod 'iAsync.network', :path => '../iAsync.network'

end

target 'iAsync.cache', :exclusive => true do
  import_pods
end

target 'iAsync.cacheTests', :exclusive => true do
  import_pods
end
