platform :ios, '8.0'
use_frameworks!

def import_pods

    pod 'iAsync.cache'      , :path => '.'
    pod 'iAsync.reactiveKit', :path => '../iAsync.reactiveKit'
    pod 'iAsync.utils'      , :path => '../iAsync.utils'
    pod 'iAsync.restkit'    , :path => '../iAsync.restkit'
    pod 'iAsync.network'    , :path => '../iAsync.network'

end

target 'iAsync.cache' do
    import_pods
end

target 'iAsync.cacheTests' do
    import_pods
end
