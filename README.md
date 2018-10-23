[官网](http://code.wequick.net/Small/cn/home)
small是android与iOS平台比较出名的轻巧的跨平台插件化框架，也正是被这一点吸引，决定将small应用到集团内部的应用引擎模块化方案中，本篇博文主要讲述本人基于small在android平台实现的定制化APP方案（运营自由配置、自由组合、自动打包）~
[特性与功能](http://code.wequick.net/Small/cn/feature)
### iOS组件化基础
iOS组件化基于[Cocoa Touch Framework][ctf]（以下简称CTF）通过[NSBundle][NSBundle]实现。
* CTF首次公开在WWDC2014，要求Xcode6 beta以上版本。
* CTF官方表示支持8.0以上系统，但在6.0、7.0上测试正常。
* 如果你的App包含了CTF，但是**Deployment Target** < 8.0，上传二进制文件到App Store时会报警中断。
受苹果官方限制，如果你的CTF没有签名，将无法实现代码级别更新。

Framework 模式无法上传到App Store。只能应用到企业版

[ctf]: https://developer.apple.com/library/ios/documentation/General/Conceptual/DevPedia-CocoaCore/Framework.html#//apple_ref/doc/uid/TP40008195-CH56-SW1
[NSBundle]: https://developer.apple.com/library/ios/documentation/Cocoa/Reference/Foundation/Classes/NSBundle_Class/index.html#//apple_ref/occ/cl/NSBundle

### 新建small项目
Small提供了`Small-pods`模版，安装Xcode模版创建空白的Small项目。
#### 安装Xcode模板
```bash
git clone https://github.com/wequick/Small.git
cd Small/iOS
cp -r Templates ~/Library/Developer/Xcode/Templates
```
#### 新建项目
`File->New->Project...`，选择`Small-pods`模板
![Small iOS Template](https://camo.githubusercontent.com/25aac173476e3a5eecdf2853b0e233bf8179bece/687474703a2f2f636f64652e7765717569636b2e6e65742f6173736574732f696d616765732f736d616c6c2d696f732d74656d706c6174652e706e67)

**自动生成两个重要的文件**  
1 库依赖配置文件`podfile`：
```js
platform :ios, '7.0'
use_frameworks!

target 'SmallAPP' do
    pod "Small", :git => 'https://github.com/wequick/Small.git'
end
```
2 路由文件`bundle.json`:
```json
{
    "version": "1.0.0",
    "bundles": [
        {
            "uri": "main",
            "pkg": "hsg.com.cn.SmallAPP.app.main"
        }
    ]
}

```
3 安装**Small**依赖
```bash
cd [your-project-path]
pod install --no-repo-update
open *.xcworkspace
```
### 插件路由的配置及使用
[插件路由](http://code.wequick.net/Small/cn/router):为了方便插件之间的跨平台调用，Small 提供了 `bundle.json` 来完成插件路由。
#### 路由配置
路由配置文件`bundle.json`部分内容如下：
```json
{
    "version": "1.0.0",    
    "bundles": [                
                {  
                   "uri": "lib.utils",                
                   "pkg": "com.example.small.lib.utils",
                   "rules": {  //会覆盖掉`Principal class`默认的启动页配置
                       "Storyboard": "storyboardName/controllerId",
                       "xib": "controllerName"
                   }               
                },                
                {                
                   "uri": "main",                
                   "pkg": "com.example.small.app.main"              
                }
               ]
               ....
}
```
#### 路由实现类 
通过在`SMBundle`的实例方法来解析路由的配置，定位到`framework`、`bundle`等程序包，从而加载到应用中进行使用。
主要功能：
```objc
+ (instancetype)bundleForName:(NSString *)name;
+ (void)setBaseUrl:(NSString *)url;
+ (void)loadLaunchableBundlesWithComplection:(void (^)(void))complection;
+ (NSArray *)allLaunchableBundles;
+ (instancetype)launchableBundleForURL:(NSURL *)url;
+ (void)registerLauncher:(SMBundleLauncher *)launcher;
+ (void)removeExternalBundles;

- (instancetype)initWithDictionary:(NSDictionary *)dictionary;

- (void)prepareForLaunch;
- (void)launchFromController:(UIViewController *)controller;
- (UIViewController *)launcherController;
```
##### **构造器**
`- (instancetype)initWithDictionary:`
```objc
NSString *bundlePath = nil;
NSString *bundleSuffix = @"bundle";
SMBundleType bundleType = SMBundleTypeAssets;
if ([pkg rangeOfString:@".app."].location != NSNotFound        
    || [pkg rangeOfString:@".lib."].location != NSNotFound)
    {
       bundleSuffix = @"framework";                      
       bundleType = SMBundleTypeApplication;           
    }
```
##### 初始化`SMBundle`的属性
`bundle.json`数据转为字典对象，并初始化`SMBundle`的属性
`uri`: 域名
`rules`: 规则
```objc
- (void)initValuesWithDictionary:(NSDictionary *)dictionar {
    NSString *uri = [dictionary objectForKey:@"uri"];
    self.uri = [Small absoluteUriFromUri:uri];

    // UI routes to principal page
    NSString *defaultTarget = @"";
    NSMutableDictionary *rules = [[NSMutableDictionary alloc] init];
    rules[@""] = defaultTarget;
    rules[@".html"] = defaultTarget;
    rules[@"/index"] = defaultTarget;
    rules[@"/index.html"] = defaultTarget;
    // UI routes to other pages
    NSDictionary *userRules = [dictionary objectForKey:@"rules"];
    if (userRules != nil) {
        [rules setValuesForKeysWithDictionary:userRules];
    }
    self.rules = rules;
}
```
##### 类方法启动组件包
更具URL来访问路由，通过解析url，启动相应的包
```
+ (instancetype)launchableBundleForURL:(NSURL *)url{
    for (SMBundle *bundle in kLaunchableBundles) {
        // Look up the matched bundle
        NSString *target;
        NSString *query;
        if ([bundle matchesRuleForURL:url target:&target query:&query]) {
            [bundle setTarget:target];
            [bundle setQuery:query];
            return bundle;
        }
    }
}
```
通过`(NSString * __autoreleasing*)outTarget`获取方式，返回对应的插件入口类
```objc
/* e.g.
*  input
*      - url: http://host/path/abc.html
*      - self.uri: http://host/path
*      - self.rules: abc.html -> AbcController
*  output
*      - target => AbcController
*/
- (BOOL)matchesRuleForURL:(NSURL *)url target:(NSString * __autoreleasing*)outTarget query:(NSString * __autoreleasing*)outQuery
{
}
```
#### 支持Storyboard作为启动页的解析
根据`SMBundle`路由配置信息，通过`SMAppBundleLauncher`的实例方法`_controllerForBundle:`加载Framework，支持storyboard加载。
1. 路由`rules`字典
```
"rules":{
"":"Main/MainViewController"
}
```
空字串(`""`)的`value`值两种格式类型：

    `"$controllerName"`: `SMAppBundleLauncher`通过反射，初始化controller
    `"storyboardName/controllerId"`:`SMAppBundleLauncher`会识别找到storyboard在更具id初始化controller
最终可以`SMBundle`实例变量`target`中得到该key(`""`)的value值，再通过`SMAppBundleLauncher`解析路由定位插件包。
具体代码: 
```objc
if ([bundle.target isEqualToString:@""]) {
        targetClazz = bundle.principalClass;
    } else {
        NSString *target = bundle.target;
        NSInteger index = [target rangeOfString:@"/"].location;
        if (index != NSNotFound) {
            // Storyboard: "$storyboardName/$controllerId"
            NSString *storyboardName = [target substringToIndex:index];
            targetBoard = [UIStoryboard storyboardWithName:storyboardName bundle:bundle];
            targetId = [target substringFromIndex:index + 1];
        } else {
            // Controller: "$controllerName"
            targetClazz = [bundle classNamed:target];
            if (targetClazz == nil && !SMStringHasSuffix(target, @"Controller")) {
            targetClazz = [bundle classNamed:[target stringByAppendingString:@"Controller"]];
        }
    }
}
```

### Framework设置
路由配置对插件包的命名有严格要求，`SMBundle`主要通过`pkg`名称包含`.app.`(模块库)/`.lib.`(工具库)来定位插件包的，否则全部默认加载bundle包。
#### 模块命名规范
* `framework`编译成功后，名称跟`Product Name`一样命名规则:
```
xx_xx_lib_xx【com_example_small_lib_utils】
xx_xx_app_xx
xx_xx_xx_xx
```
>注意lib、app这些对查找framework文件相当重要，这所以会有`_`，是small对`.`做了替换

### 设置加载模块的入口类
1. **info.plist**方式实现
在 `framework`模块工程的**info.plist**文件中添加`Principal class`字段：
```
<key>NSPrincipalClass</key>
<string>ESHomeController</string> //指定入口类名
```
2. **bundle.json**路由方式实现
通过设置**bundle.json**的`rules`字典，指定初始化库的入口
```
"rules": {  
    "Storyboard": "storyboardName/controllerId",
           "xib": "controllerName"
}  
```
> **bundle.json**中配置的入口，优先于`info.plist`中的`Principal class`的入口。

#### 主工程设置
* 工程名可根据自己需要进行命名，eg：`Small.Main`；
* `framework`添加到主工程，不以Linked方式进行添加，使用`Build Phases`中的`Copy Bundle Resources` 选项，将`framework`拖动添加其中即可，这样可以完成对`framework`编译完后的拷贝.

#### 测试
完成添加，进入测试。使用过程中，有可以模块更新代码后，主工程调用发现功能未更新，这时候需要清理工程，重新编译；或者修改编译包配置，从而时时更新。
![](https://img-blog.csdn.net/20160718094828722?watermark/2/text/aHR0cDovL2Jsb2cuY3Nkbi5uZXQv/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70/gravity/SouthEast)
![](https://img-blog.csdn.net/20160718094836316?watermark/2/text/aHR0cDovL2Jsb2cuY3Nkbi5uZXQv/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70/gravity/SouthEast)

### 两种开发模式
#### [Sample](Sample)使用者模式
使用场景：作为第三方集成到自己的项目
包含两个特殊的文件`podfile`和`Small-subprojects.rb`安装脚本文件。

##### 依赖本地的**Small**库
```
platform :ios, '7.0'
use_frameworks!

target 'Sample' do
    pod "Small", :path => "../../"
end
```
##### `Small-subprojects.rb`安装脚本文件
通过脚本来设置`build settings`中的**FRAMEWORK_SEARCH_PATHS**配置：
```
config.build_settings['FRAMEWORK_SEARCH_PATHS'] << "$(CONFIGURATION_BUILD_DIR)/**"
puts "Small: Add framework search paths for '#{dep.name}'"
```
#### [DevSample](DevSample)开发者模式
使用场景：需要对Small框架集成自己的功能需求时，可以使用该Demo快速部署对Small框架的开发环境
> 需要去除并行编译模式：`Edit Scheme...->Build->Build Options-> [ ] Parallelize Build`
    
> 各个组件需要签名后才支持代码级别更新。示例中更新例子为xib内容更新。<br/>

[使用Small创建iOS工程目录](https://blog.csdn.net/zhaowensky_126/article/details/51939230)
[Small UI route文档](https://github.com/wequick/Small/wiki/UI-route)
