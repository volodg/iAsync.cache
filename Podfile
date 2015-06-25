platform :ios, '8.0'
use_frameworks!

def import_pods
    
    pod 'iAsync.async'  , :path => '../iAsync.async'
    pod 'iAsync.utils'  , :path => '../iAsync.utils'
    pod 'iAsync.restkit', :path => '../iAsync.restkit'
    pod 'iAsync.network', :path => '../iAsync.network'
    
end

target 'iAsync.cache', :exclusive => true do
    import_pods
end

target 'iAsync.cacheTests', :exclusive => true do
    import_pods
end
