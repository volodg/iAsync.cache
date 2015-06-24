platform :ios, '8.0'
use_frameworks!

def import_pods

pod 'iAsync.async'  , :path => '../iAsync.async'
pod 'iAsync.utils'  , :path => '../iAsync.utils'
pod 'iAsync.network', :path => '../iAsync.network'

end

target 'iAsync.social', :exclusive => true do
  import_pods
end

target 'iAsync.socialTests', :exclusive => true do
  import_pods
end
