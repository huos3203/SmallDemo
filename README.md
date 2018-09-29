### 工程配置要点
#### `SMBundle类`和`bundle.json`配置文件
在SMBundle类中，方法
```objc
- (instancetype)initWithDictionary:(NSDictionary *)dictionary
```
根据`bundle.json`配置文件信息查找`framework`、`bundle`文件，从而加载到应用中进行使用。
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
以上代码是用来加载`framework`文件，`pkg`名称必须包含`.app.`(模块库)/`.lib.`(工具库)，否则全部默认加载bundle包。因此`bundle.json`文件可以是这样的：
```json
"version": "1.0.0",    
"bundles": [                
            {  
               "uri": "lib.utils",                
               "pkg": "com.example.small.lib.utils",
               "rules": {  //会覆盖掉`Principal class`默认的启动页配置
                   "": "storyboardName/controllerId",
                   "": "controllerName"
               }               
            },                
            {                
               "uri": "main",                
               "pkg": "com.example.small.app.main"              
            }
           ]
```

### 支持Storyboard作为启动页的解析
`SMAppBundleLauncher`来解析bundle.json获取到如下：
在rules字典中设置：`""`key设置为`Storyboard: "$storyboardName/$controllerId"`
1. `SMAppBundleLauncher.h`类中家在从storyboard初始化UI的方法，关键属性target的解析。
```objc
- (UIViewController *)_controllerForBundle:(SMBundle *)bundle
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
.......
......
}
```
2. 从bundle.json中解析rules字典
```objc
////解析bundle.json中的rules规则字典
////
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
3. 解析域名和rules字典
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

### workspace/project设置
#### `framework`模块工程设置
* `framework`编译成功后，名称跟`Product Name`一样命名规则:
```
xx_xx_lib_xx【com_example_small_lib_utils】
xx_xx_app_xx
xx_xx_xx_xx
```
注意lib、app这些对查找framework文件相当重要，这所以会有`_`，是small对`.`做了替换
* `Principal class`设置，指定模块入口
在 `framework`模块工程的info.plist文件中添加`Principal class`字段：
```
<key>NSPrincipalClass</key>
<string>ESHomeController</string> //指定入口类名
```
或者通过bundle.json 来指定多个页面：`支持storyboard页面使用`
```
"rules": {  //会覆盖掉`Principal class`默认的启动页配置
"Storyboard": "storyboardName/controllerId",
"xib": "controllerName"
}  
```
#### 主工程设置
* 工程名可根据自己需要进行命名，eg：`Small.Main`；
* `framework`添加到主工程，不以Linked方式进行添加，使用`Build Phases`中的`Copy Bundle Resources` 选项，将`framework`拖动添加其中即可，这样可以完成对`framework`编译完后的拷贝.
### 测试
完成添加，进入测试。使用过程中，有可以模块更新代码后，主工程调用发现功能未更新，这时候需要清理工程，重新编译；或者修改编译包配置，从而时时更新。
